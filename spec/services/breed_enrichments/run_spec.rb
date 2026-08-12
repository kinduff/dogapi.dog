# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedEnrichments::Run do
  subject(:record) { described_class.call(breed, agent: agent) }

  let(:breed) { create(:breed, name: "Akita") }
  let(:agent) { instance_double(BreedEnrichments::Agent, call: answer) }
  let(:answer) do
    BreedEnrichments::Agent::Result.new(
      attributes: {
        "name" => "Akita",
        "confidence" => "high",
        "sources" => [{"url" => "https://www.akc.org/dog-breeds/akita/"}],
        "male_height" => {"min" => 66, "max" => 71},
        "traits" => {"energy" => 9}
      },
      raw: {},
      usage: {}
    )
  end

  it "keeps what survives validation and records what did not" do
    expect(record).to be_applied
    expect(breed.reload.male_height).to eq("min" => 66, "max" => 71)
    expect(breed.traits).to eq({})
    expect(record.rejections.first["field"]).to eq("traits.energy")
  end
end
