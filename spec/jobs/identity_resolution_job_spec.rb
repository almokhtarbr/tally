require "rails_helper"

RSpec.describe IdentityResolutionJob, type: :job do
  let(:project) { create(:project) }

  it "re-links anonymous events to the identified user" do
    anon_profile = create(:user_profile, project: project, external_id: "anon_abc")
    identified_profile = create(:user_profile, project: project, external_id: "user@test.com")
    event = create(:event, project: project, user_profile: anon_profile, name: "page_view")

    IdentityResolutionJob.perform_now(
      project_id: project.id,
      anonymous_id: "anon_abc",
      user_profile_id: identified_profile.id
    )

    expect(event.reload.user_profile_id).to eq(identified_profile.id)
  end

  it "merges properties from anonymous to identified" do
    anon_profile = create(:user_profile, project: project, external_id: "anon_abc",
      properties: { "utm_source" => "google" })
    identified_profile = create(:user_profile, project: project, external_id: "user@test.com",
      properties: { "name" => "Jane" })

    IdentityResolutionJob.perform_now(
      project_id: project.id,
      anonymous_id: "anon_abc",
      user_profile_id: identified_profile.id
    )

    identified_profile.reload
    expect(identified_profile.properties["utm_source"]).to eq("google")
    expect(identified_profile.properties["name"]).to eq("Jane")
  end

  it "deletes the anonymous profile" do
    anon_profile = create(:user_profile, project: project, external_id: "anon_abc")
    identified_profile = create(:user_profile, project: project, external_id: "user@test.com")

    IdentityResolutionJob.perform_now(
      project_id: project.id,
      anonymous_id: "anon_abc",
      user_profile_id: identified_profile.id
    )

    expect(UserProfile.find_by(id: anon_profile.id)).to be_nil
  end

  it "updates first_seen_at if anonymous was earlier" do
    anon_profile = create(:user_profile, project: project, external_id: "anon_abc", first_seen_at: 30.days.ago)
    identified_profile = create(:user_profile, project: project, external_id: "user@test.com", first_seen_at: 1.day.ago)

    IdentityResolutionJob.perform_now(
      project_id: project.id,
      anonymous_id: "anon_abc",
      user_profile_id: identified_profile.id
    )

    expect(identified_profile.reload.first_seen_at).to be_within(1.second).of(30.days.ago)
  end

  it "handles missing anonymous profile gracefully" do
    identified_profile = create(:user_profile, project: project, external_id: "user@test.com")

    expect {
      IdentityResolutionJob.perform_now(
        project_id: project.id,
        anonymous_id: "nonexistent",
        user_profile_id: identified_profile.id
      )
    }.not_to raise_error
  end
end
