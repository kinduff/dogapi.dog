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

  describe "rate limiting" do
    # The waits are real seconds in production and pointless ones in a spec.
    before { allow_any_instance_of(described_class).to receive(:sleep) }

    it "retries after a 429 and succeeds" do
      stub_request(:get, url)
        .to_return(status: 429, headers: {"Retry-After" => "1"})
        .then.to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

      expect(download.first.bytesize).to eq(image_bytes.bytesize)
    end

    it "retries after a 503" do
      stub_request(:get, url)
        .to_return(status: 503)
        .then.to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

      expect(download.last).to eq("image/jpeg")
    end

    it "gives up after the retry budget" do
      stub_request(:get, url).to_return(status: 429)

      expect { download }.to raise_error(described_class::Error, "429 after #{described_class::MAX_RETRIES} retries for #{url}")
      expect(a_request(:get, url)).to have_been_made.times(described_class::MAX_RETRIES + 1)
    end

    it "waits for as long as Retry-After asks" do
      stub_request(:get, url)
        .to_return(status: 429, headers: {"Retry-After" => "7"})
        .then.to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

      expect_any_instance_of(described_class).to receive(:sleep).with(7)

      download
    end

    it "backs off exponentially when no Retry-After is given" do
      stub_request(:get, url)
        .to_return(status: 429)
        .then.to_return(status: 429)
        .then.to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

      waits = []
      allow_any_instance_of(described_class).to receive(:sleep) { |_, seconds| waits << seconds }

      download

      expect(waits).to eq([2, 4])
    end

    it "never waits longer than the cap" do
      stub_request(:get, url)
        .to_return(status: 429, headers: {"Retry-After" => "9999"})
        .then.to_return(status: 200, body: image_bytes, headers: {"Content-Type" => "image/jpeg"})

      expect_any_instance_of(described_class).to receive(:sleep).with(described_class::MAX_BACKOFF)

      download
    end
  end

  it "turns a timeout into a downloader error" do
    stub_request(:get, url).to_timeout

    expect { download }.to raise_error(described_class::Error)
  end
end
