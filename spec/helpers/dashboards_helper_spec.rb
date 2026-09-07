require "rails_helper"

RSpec.describe DashboardsHelper, type: :helper do
  describe "#sparkline" do
    it "is nil for a too-short or flat-zero series" do
      expect(helper.sparkline([])).to be_nil
      expect(helper.sparkline([ 5 ])).to be_nil
      expect(helper.sparkline([ 0, 0, 0 ])).to be_nil
    end

    it "renders an svg polyline with one point per value" do
      svg = helper.sparkline([ 0, 2, 1, 4 ], width: 30, height: 10)
      expect(svg).to include("<svg")
      expect(svg).to include("<polyline")

      points = svg[/points="([^"]+)"/, 1].split
      expect(points.length).to eq(4)
      expect(points.first.split(",").first.to_f).to eq(0.0)
      expect(points.last.split(",").first.to_f).to eq(30.0)
    end

    it "puts the highest value nearest the top of the box" do
      svg = helper.sparkline([ 1, 9 ], width: 10, height: 10)
      ys = svg[/points="([^"]+)"/, 1].split.map { |p| p.split(",").last.to_f }
      expect(ys.last).to be < ys.first
    end
  end
end
