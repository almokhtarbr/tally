require "rails_helper"

RSpec.describe Anomaly, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it "requires event_name, anomaly_type, severity, expected/actual values, z_score, detected_at" do
      anomaly = Anomaly.new
      expect(anomaly).not_to be_valid
      expect(anomaly.errors[:event_name]).to be_present
      expect(anomaly.errors[:anomaly_type]).to be_present
      expect(anomaly.errors[:detected_at]).to be_present
    end

    it "validates anomaly_type inclusion" do
      anomaly = build(:anomaly, anomaly_type: "invalid")
      expect(anomaly).not_to be_valid
    end

    it "validates severity inclusion" do
      anomaly = build(:anomaly, severity: "invalid")
      expect(anomaly).not_to be_valid
    end

    it "is valid with correct attributes" do
      anomaly = build(:anomaly, project: project)
      expect(anomaly).to be_valid
    end
  end

  describe "scopes" do
    it ".active returns unresolved anomalies" do
      active = create(:anomaly, project: project, resolved_at: nil)
      resolved = create(:anomaly, project: project, resolved_at: Time.current)
      expect(Anomaly.active).to include(active)
      expect(Anomaly.active).not_to include(resolved)
    end

    it ".recent orders by detected_at desc" do
      old = create(:anomaly, project: project, detected_at: 2.hours.ago)
      recent = create(:anomaly, project: project, detected_at: 1.hour.ago)
      expect(Anomaly.recent.first).to eq(recent)
    end
  end

  describe "#active?" do
    it "returns true when resolved_at is nil" do
      anomaly = build(:anomaly, resolved_at: nil)
      expect(anomaly.active?).to be true
    end

    it "returns false when resolved" do
      anomaly = build(:anomaly, resolved_at: Time.current)
      expect(anomaly.active?).to be false
    end
  end

  describe "#resolve!" do
    it "sets resolved_at" do
      anomaly = create(:anomaly, project: project)
      anomaly.resolve!
      expect(anomaly.resolved_at).to be_present
    end
  end

  describe "#change_pct" do
    it "calculates percentage change" do
      anomaly = build(:anomaly, expected_value: 100, actual_value: 150)
      expect(anomaly.change_pct).to eq(50.0)
    end

    it "handles zero expected" do
      anomaly = build(:anomaly, expected_value: 0, actual_value: 10)
      expect(anomaly.change_pct).to eq(0)
    end
  end

  describe "#description" do
    it "describes a spike" do
      anomaly = build(:anomaly, anomaly_type: "spike", event_name: "$error", expected_value: 10, actual_value: 50)
      expect(anomaly.description).to include("spiked")
    end

    it "describes a drop" do
      anomaly = build(:anomaly, anomaly_type: "drop", event_name: "signup", expected_value: 45, actual_value: 17)
      expect(anomaly.description).to include("dropped")
    end

    it "describes absence" do
      anomaly = build(:anomaly, anomaly_type: "absence", event_name: "purchase", expected_value: 10, actual_value: 0)
      expect(anomaly.description).to include("No purchase")
    end
  end

  describe ".severity_for_z_score" do
    it "returns critical for z > 4" do
      expect(Anomaly.severity_for_z_score(4.5)).to eq("critical")
    end

    it "returns warning for z > 3" do
      expect(Anomaly.severity_for_z_score(3.5)).to eq("warning")
    end

    it "returns info for z <= 3" do
      expect(Anomaly.severity_for_z_score(2.8)).to eq("info")
    end
  end
end
