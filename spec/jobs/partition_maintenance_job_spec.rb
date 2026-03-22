require "rails_helper"

RSpec.describe PartitionMaintenanceJob, type: :job do
  it "creates partition tables without error" do
    expect {
      PartitionMaintenanceJob.perform_now
    }.not_to raise_error
  end

  it "is idempotent (can run multiple times)" do
    PartitionMaintenanceJob.perform_now
    expect {
      PartitionMaintenanceJob.perform_now
    }.not_to raise_error
  end
end
