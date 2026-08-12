# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::Downloader do
  let(:url) { "https://upload.wikimedia.org/akita.jpg" }
  let(:image_bytes) { Rails.root.join("spec/fixtures/files/dog.jpg").binread }

  def download(target = url, **options)
    described_class.call(target, **options) { |io, content_type| [io.read, content_type] }
  end

  it "yields the body and its content type" do
    stub_request(:get, url).to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

    body, content_type = download

    expect(body.bytesize).to eq(image_bytes.bytesize)
    expect(content_type).to eq("image/jpeg")
  end

  it "ignores charset noise on the content type" do
    stub_request(:get, url).to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg; charset=binary"})

    expect(download.last).to eq("image/jpeg")
  end

  it "follows redirects" do
    stub_request(:get, url).to_return(status: 302, headers: {"Location" => "https://upload.wikimedia.org/real.jpg"})
    stub_request(:get, "https://upload.wikimedia.org/real.jpg")
      .to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

    expect(download.first.bytesize).to eq(image_bytes.bytesize)
  end

  it "gives up on a redirect loop" do
    stub_request(:get, url).to_return(status: 302, headers: {"Location" => url})

    expect { download }.to raise_error(described_class::Error, /too many redirects/)
  end

  it "rejects a non image response" do
    stub_request(:get, url).to_return(status: 200, body: "<html>", headers: {"Content-Type" => "text/html"})

    expect { download }.to raise_error(described_class::Error, /unsupported content type text\/html/)
  end

  it "rejects an http error" do
    stub_request(:get, url).to_return(status: 404, body: "")

    expect { download }.to raise_error(described_class::Error, /404/)
  end

  it "rejects a body over the limit" do
    stub_request(:get, url).to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

    expect { download(max_bytes: 10) }.to raise_error(described_class::Error, /exceeds/)
  end

  it "rejects an oversized content-length before reading the body" do
    stub_request(:get, url).to_return(
      status: 200,
      body: image_bytes,
      headers: {"Content-Type" => "image/jpeg", "Content-Length" => (BreedImage::MAX_BYTE_SIZE + 1).to_s}
    )

    expect { download }.to raise_error(described_class::Error, /content-length/)
  end

  it "rejects an empty body" do
    stub_request(:get, url).to_return(status: 200, body: "", headers: {"Content-Type" => "image/jpeg"})

    expect { download }.to raise_error(described_class::Error, /empty body/)
  end

  it "refuses a non http scheme" do
    expect { download("file:///etc/passwd") }.to raise_error(described_class::Error, /not an http/)
  end

  it "turns a timeout into a downloader error" do
    stub_request(:get, url).to_timeout

    expect { download }.to raise_error(described_class::Error)
  end
end
