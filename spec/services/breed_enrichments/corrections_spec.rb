# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedEnrichments::Corrections do
  subject(:outstanding) { described_class.outstanding }

  let(:breed) do
    create(:breed, name: "Akita", life: {"min" => 10, "max" => 14}, male_weight: {"min" => 32, "max" => 39})
  end

  def run_proposing(*corrections, breed: self.breed, **attributes)
    create(:breed_enrichment, breed: breed, raw_response: {"corrections" => corrections}, **attributes)
  end

  def correction(field, min, max, note: "a source says so")
    {"field" => field, "min" => min, "max" => max, "note" => note}
  end

  it "reads what the run proposed against what the breed stores" do
    run_proposing(correction("life", 12, 15))

    expect(outstanding.size).to eq(1)
    expect(outstanding.first).to have_attributes(
      field: "life",
      from: {"min" => 10, "max" => 14},
      to: {"min" => 12, "max" => 15},
      note: "a source says so"
    )
  end

  it "drops a correction that asks for the range already stored" do
    run_proposing(correction("life", 10, 14))

    expect(outstanding).to be_empty
  end

  it "drops a correction outside what the field can plausibly hold" do
    run_proposing(correction("life", 10, 400), correction("male_weight", 30, 40))

    expect(outstanding.map(&:field)).to eq(["male_weight"])
  end

  it "drops an inverted or incomplete range" do
    run_proposing(correction("life", 15, 12), {"field" => "male_weight", "min" => 30})

    expect(outstanding).to be_empty
  end

  it "ignores a field enrichment writes itself" do
    run_proposing(correction("male_height", 66, 71))

    expect(outstanding).to be_empty
  end

  it "reads only the newest run for a breed" do
    run_proposing(correction("life", 12, 15), created_at: 2.days.ago)
    run_proposing(correction("life", 11, 13), created_at: 1.day.ago)

    expect(outstanding.map(&:to)).to eq([{"min" => 11, "max" => 13}])
  end

  describe "accepting" do
    before { run_proposing(correction("life", 12, 15)) }

    it "writes the corrected range onto the breed" do
      described_class.accept(outstanding.first)

      expect(breed.reload.life).to eq("min" => 12, "max" => 15)
    end

    it "records what it replaced, so the change can be read back" do
      described_class.accept(outstanding.first)

      accepted = breed.breed_enrichments.ordered.first.payload.fetch("accepted_corrections")
      expect(accepted.size).to eq(1)
      expect(accepted.first).to include(
        "field" => "life",
        "from" => {"min" => 10, "max" => 14},
        "to" => {"min" => 12, "max" => 15}
      )
    end

    it "stops being outstanding once accepted" do
      described_class.accept(outstanding.first)

      expect(described_class.outstanding).to be_empty
    end

    it "leaves the fields enrichment already wrote alone" do
      expect { described_class.accept(outstanding.first) }
        .not_to change { breed.reload.male_weight }
    end
  end

  describe "reverting" do
    let(:run) { breed.breed_enrichments.ordered.first }

    before do
      run_proposing(correction("life", 12, 15), correction("male_weight", 30, 40))
      described_class.outstanding.each { |item| described_class.accept(item) }
    end

    it "puts every replaced range back" do
      described_class.revert(run)

      breed.reload
      expect(breed.life).to eq("min" => 10, "max" => 14)
      expect(breed.male_weight).to eq("min" => 32, "max" => 39)
    end

    it "makes the corrections outstanding again" do
      described_class.revert(run)

      expect(described_class.outstanding.map(&:field)).to contain_exactly("life", "male_weight")
    end

    it "puts back an empty object for a field that had nothing in it" do
      breed.update!(female_weight: {})
      run.update!(raw_response: {"corrections" => [correction("female_weight", 25, 30)]})
      described_class.accept(described_class.outstanding.first)

      described_class.revert(run.reload)

      expect(breed.reload.female_weight).to eq({})
    end

    it "does nothing to a run that had nothing accepted" do
      other = run_proposing(correction("life", 11, 13), breed: create(:breed, name: "Beagle"))

      expect(described_class.revert(other)).to be_empty
    end

    it "lists the runs an undo would touch" do
      expect(described_class.accepted_runs).to contain_exactly(run)
    end

    # Assigning a value equal to a stale one reads as no change at all, and the
    # write is dropped without complaint.
    it "puts the range back even when handed a run whose breed is out of date" do
      stale = BreedEnrichment.find(run.id)
      stale.breed.life

      breed.update!(life: {"min" => 1, "max" => 2})
      described_class.revert(stale)

      expect(breed.reload.life).to eq("min" => 10, "max" => 14)
    end
  end
end
