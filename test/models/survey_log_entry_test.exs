defmodule Ask.SurveyLogEntryTest do
  use Ask.ModelCase

  alias Ask.SurveyLogEntry

  @valid_attrs %{action_data: "some content", action_type: "some content", channel_id: 42, disposition: "some content", mode: "some content", respondent_id: 42, respondent_hashed_number: "some content", survey_id: 42, timestamp: DateTime.utc_now}

  test "changeset with valid attributes" do
    changeset = SurveyLogEntry.changeset(%SurveyLogEntry{}, @valid_attrs)
    assert changeset.valid?
  end
end
