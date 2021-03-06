defmodule Ask.RespondentControllerTest do
  use Ask.ConnCase
  use Ask.TestHelpers
  use Ask.DummySteps

  alias Ask.{QuotaBucket, Survey, Response, Respondent, ShortLink, Stats}

  describe "normal" do
    setup %{conn: conn} do
      user = insert(:user)
      conn = conn
        |> put_private(:test_user, user)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user: user}
    end

    test "returns code 200 and empty list if there are no entries", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      survey = insert(:survey, project: project)
      conn = get conn, project_survey_respondent_path(conn, :index, project.id, survey.id)
      assert json_response(conn, 200)["data"]["respondents"] == []
      assert json_response(conn, 200)["meta"]["count"] == 0
    end

    test "fetches responses on index", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      survey = insert(:survey, project: project)
      questionnaire = insert(:questionnaire, project: project)
      respondent = insert(:respondent, survey: survey, mode: ["sms"], questionnaire_id: questionnaire.id, disposition: "completed")
      response = insert(:response, respondent: respondent, value: "Yes")
      response = Response |> Repo.get(response.id)
      respondent = Respondent |> Repo.get(respondent.id)
      conn = get conn, project_survey_respondent_path(conn, :index, project.id, survey.id)
      assert json_response(conn, 200)["data"]["respondents"] == [%{
                                                     "id" => respondent.id,
                                                     "phone_number" => respondent.hashed_number,
                                                     "survey_id" => survey.id,
                                                     "mode" => ["sms"],
                                                     "effective_modes" => nil,
                                                     "questionnaire_id" => questionnaire.id,
                                                     "disposition" => "completed",
                                                     "date" => DateTime.to_iso8601(response.updated_at),
                                                     "updated_at" => NaiveDateTime.to_iso8601(respondent.updated_at),
                                                     "responses" => [
                                                       %{
                                                         "value" => response.value,
                                                         "name" => response.field_name
                                                       }
                                                     ]
                                                  }]
    end

    test "forbid index access if the project does not belong to the current user", %{conn: conn} do
      survey = insert(:survey)
      respondent = insert(:respondent, survey: survey)
      insert(:response, respondent: respondent, value: "Yes")
      assert_error_sent :forbidden, fn ->
        get conn, project_survey_respondent_path(conn, :index, survey.project.id, survey.id)
      end
    end

    test "lists stats for a given survey", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)
      survey = insert(:survey, project: project, cutoff: 10, started_at: t)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      insert_list(10, :respondent, survey: survey, questionnaire: questionnaire, disposition: "partial")
      insert(:respondent, survey: survey, disposition: "completed", questionnaire: questionnaire, updated_at: Ecto.DateTime.cast!("2016-01-01T10:00:00Z"))
      insert(:respondent, survey: survey, disposition: "completed", questionnaire: questionnaire, updated_at: Ecto.DateTime.cast!("2016-01-01T11:00:00Z"))
      insert_list(3, :respondent, survey: survey, disposition: "completed", questionnaire: questionnaire, updated_at: Ecto.DateTime.cast!("2016-01-02T10:00:00Z"))

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      data = json_response(conn, 200)["data"]
      total = 15.0

      string_questionnaire_id = to_string(questionnaire.id)

      assert data["id"] == survey.id
      assert data["respondents_by_disposition"] == %{
        "uncontacted" => %{
          "count" => 0,
          "percent" => 0.0,
          "detail" => %{
            "registered" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "queued" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "failed" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
        "contacted" => %{
          "count" => 0,
          "percent" => 0.0,
          "detail" => %{
            "contacted" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "unresponsive" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
        "responsive" => %{
          "count" => 15,
          "percent" => 100.0,
          "detail" => %{
            "started" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "breakoff" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "partial" => %{"count" => 10, "percent" => 100*10/total, "by_reference" => %{string_questionnaire_id => 10}},
            "completed" => %{"count" => 5, "percent" => 100*5/total, "by_reference" => %{string_questionnaire_id => 5}},
            "ineligible" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "refused" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "rejected" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
      }

      cumulative_percentages = data["cumulative_percentages"][to_string(questionnaire.id)]

      assert Enum.at(cumulative_percentages, 0)["date"] == "2016-01-01"
      assert Enum.at(cumulative_percentages, 0)["percent"] == 20
      assert Enum.at(cumulative_percentages, 1)["date"] == "2016-01-02"
      assert Enum.at(cumulative_percentages, 1)["percent"] == 50
      assert data["total_respondents"] == 15
    end

    test "cumulative percentages for a survey with two questionnaires and two modes", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)
      q1 = insert(:questionnaire, name: "test 1", project: project, steps: @dummy_steps)
      q2 = insert(:questionnaire, name: "test 2", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, questionnaires: [q1, q2], cutoff: 10, mode: [["sms"], ["ivr"]], started_at: t)
      insert_list(10, :respondent, survey: survey, questionnaire: q1, disposition: "partial")
      insert(:respondent, survey: survey, disposition: "completed", questionnaire: q1, mode: ["sms"], updated_at: Ecto.DateTime.cast!("2016-01-01T10:00:00Z"))
      insert(:respondent, survey: survey, disposition: "completed", questionnaire: q2, mode: ["sms"], updated_at: Ecto.DateTime.cast!("2016-01-01T11:00:00Z"))
      insert_list(3, :respondent, survey: survey, disposition: "completed", questionnaire: q2, mode: ["ivr"], updated_at: Ecto.DateTime.cast!("2016-01-02T10:00:00Z"))

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      data = json_response(conn, 200)["data"]

      assert Enum.at(data["cumulative_percentages"]["#{q1.id}sms"], 0)["date"] == "2016-01-01"
      assert Enum.at(data["cumulative_percentages"]["#{q1.id}sms"], 0)["percent"] == 10
      assert Enum.at(data["cumulative_percentages"]["#{q2.id}sms"], 0)["date"] == "2016-01-01"
      assert Enum.at(data["cumulative_percentages"]["#{q2.id}sms"], 0)["percent"] == 10
      assert Enum.at(data["cumulative_percentages"]["#{q2.id}ivr"], 0)["date"] == "2016-01-01"
      assert Enum.at(data["cumulative_percentages"]["#{q2.id}ivr"], 0)["percent"] == 0
      assert Enum.at(data["cumulative_percentages"]["#{q2.id}ivr"], 1)["date"] == "2016-01-02"
      assert Enum.at(data["cumulative_percentages"]["#{q2.id}ivr"], 1)["percent"] == 30
    end

    test "cumulative percentages for a survey with two modes", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)
      q1 = insert(:questionnaire, name: "test 1", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, questionnaires: [q1], cutoff: 10, mode: [["sms"], ["ivr"]], started_at: t)
      insert_list(10, :respondent, survey: survey, questionnaire: q1, disposition: "partial")
      insert(:respondent, survey: survey, disposition: "completed", questionnaire: q1, mode: ["sms"], updated_at: Ecto.DateTime.cast!("2016-01-01T10:00:00Z"))
      insert(:respondent, survey: survey, disposition: "completed", questionnaire: q1, mode: ["sms"], updated_at: Ecto.DateTime.cast!("2016-01-01T11:00:00Z"))
      insert_list(3, :respondent, survey: survey, disposition: "completed", questionnaire: q1, mode: ["ivr"], updated_at: Ecto.DateTime.cast!("2016-01-02T10:00:00Z"))

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      data = json_response(conn, 200)["data"]

      assert Enum.at(data["cumulative_percentages"]["ivr"], 0)["date"] == "2016-01-01"
      assert Enum.at(data["cumulative_percentages"]["ivr"], 0)["percent"] == 0
      assert Enum.at(data["cumulative_percentages"]["ivr"], 1)["date"] == "2016-01-02"
      assert Enum.at(data["cumulative_percentages"]["ivr"], 1)["percent"] == 30
      assert Enum.at(data["cumulative_percentages"]["sms"], 0)["date"] == "2016-01-01"
      assert Enum.at(data["cumulative_percentages"]["sms"], 0)["percent"] == 20
    end

    test "stats do not crash when a respondent has 'completed' disposition but no 'completed_at'", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)
      survey = insert(:survey, project: project, cutoff: 1, started_at: t)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      insert(:respondent, survey: survey, disposition: "completed", questionnaire: questionnaire, updated_at: t |> Timex.to_erl |> Ecto.DateTime.from_erl)

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      data = json_response(conn, 200)["data"]

      cumulative_percentages = data["cumulative_percentages"][to_string(questionnaire.id)]
      assert Enum.at(cumulative_percentages, 0)["date"] == "2016-01-01"
      assert Enum.at(cumulative_percentages, 0)["percent"] == 100
    end

    test "lists stats for a given survey with quotas", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)
      survey = insert(:survey, project: project, cutoff: 10, started_at: t, quota_vars: ["gender"])
      bucket_1 = insert(:quota_bucket, survey: survey, condition: %{gender: "male"}, quota: 4, count: 2)
      bucket_2 = insert(:quota_bucket, survey: survey, condition: %{gender: "female"}, quota: 3, count: 3)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      insert_list(10, :respondent, survey: survey, questionnaire: questionnaire, disposition: "partial")
      insert(:respondent, survey: survey, questionnaire: questionnaire, disposition: "completed", updated_at: Ecto.DateTime.cast!("2016-01-01T10:00:00Z"), quota_bucket: bucket_1)
      insert(:respondent, survey: survey, questionnaire: questionnaire, disposition: "completed", updated_at: Ecto.DateTime.cast!("2016-01-01T11:00:00Z"), quota_bucket: bucket_1)
      insert(:respondent, survey: survey, questionnaire: questionnaire, disposition: "rejected", updated_at: Ecto.DateTime.cast!("2016-01-02T10:00:00Z"), quota_bucket: bucket_2)
      insert_list(3, :respondent, survey: survey, questionnaire: questionnaire, disposition: "completed", updated_at: Ecto.DateTime.cast!("2016-01-02T10:00:00Z"), quota_bucket: bucket_2)

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      data = json_response(conn, 200)["data"]
      total = 16.0

      assert data["id"] == survey.id
      assert data["respondents_by_disposition"] == %{
        "uncontacted" => %{
          "count" => 0,
          "percent" => 0.0,
          "detail" => %{
            "registered" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "queued" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "failed" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
        "contacted" => %{
          "count" => 0,
          "percent" => 0.0,
          "detail" => %{
            "contacted" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "unresponsive" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
        "responsive" => %{
          "count" => 16,
          "percent" => 100.0,
          "detail" => %{
            "started" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "breakoff" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "partial" => %{"count" => 10, "percent" => 100*10/total, "by_reference" => %{"" => 10}},
            "completed" => %{"count" => 5, "percent" => 100*5/total, "by_reference" => %{"#{bucket_1.id}" => 2, "#{bucket_2.id}" => 3}},
            "ineligible" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "refused" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "rejected" => %{"count" => 1, "percent" => 100*1/total, "by_reference" => %{"#{bucket_2.id}" => 1}},
          },
        },
      }

      cumulative_percentages = data["cumulative_percentages"]
      assert Enum.at(cumulative_percentages["#{bucket_1.id}"], 0)["date"] == "2016-01-01"
      assert abs(Enum.at(cumulative_percentages["#{bucket_1.id}"], 0)["percent"] - 28) < 1
      assert Enum.at(cumulative_percentages["#{bucket_2.id}"], 0)["date"] == "2016-01-01"
      assert Enum.at(cumulative_percentages["#{bucket_2.id}"], 0)["percent"] == 0
      assert Enum.at(cumulative_percentages["#{bucket_2.id}"], 1)["date"] == "2016-01-02"
      assert abs(Enum.at(cumulative_percentages["#{bucket_2.id}"], 1)["percent"] - 42) < 1
      assert data["total_respondents"] == 16
    end

    test "lists stats for a given survey, with dispositions", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)
      survey = insert(:survey, project: project, cutoff: 10, started_at: t)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      insert_list(10, :respondent, survey: survey, state: "pending", disposition: "registered")
      insert(:respondent, survey: survey, state: "completed", questionnaire: questionnaire, disposition: "partial", updated_at: Ecto.DateTime.cast!("2016-01-01T10:00:00Z"))
      insert(:respondent, survey: survey, state: "completed", questionnaire: questionnaire, disposition: "completed", updated_at: Ecto.DateTime.cast!("2016-01-01T11:00:00Z"))
      insert_list(3, :respondent, survey: survey, state: "completed", questionnaire: questionnaire, disposition: "ineligible", updated_at: Ecto.DateTime.cast!("2016-01-02T10:00:00Z"))

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      data = json_response(conn, 200)["data"]
      total = 15.0

      string_questionnaire_id = to_string(questionnaire.id)
      assert data["id"] == survey.id
      assert data["respondents_by_disposition"] == %{
        "uncontacted" => %{
          "count" => 10,
          "percent" => 100*10/total,
          "detail" => %{
            "registered" => %{"count" => 10, "percent" => 100*10/total, "by_reference" => %{"" => 10}},
            "queued" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "failed" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
        "contacted" => %{
          "count" => 0,
          "percent" => 0.0,
          "detail" => %{
            "contacted" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "unresponsive" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
        "responsive" => %{
          "count" => 5,
          "percent" => 100*5/total,
          "detail" => %{
            "started" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "breakoff" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "partial" => %{"count" => 1, "percent" => 100*1/total, "by_reference" => %{string_questionnaire_id => 1}},
            "completed" => %{"count" => 1, "percent" => 100*1/total, "by_reference" => %{string_questionnaire_id => 1}},
            "ineligible" => %{"count" => 3, "percent" => 100*3/total, "by_reference" => %{string_questionnaire_id => 3}},
            "refused" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            "rejected" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
          },
        },
      }

      cumulative_percentages = data["cumulative_percentages"][to_string(questionnaire.id)]

      assert Enum.at(cumulative_percentages, 0)["date"] == "2016-01-01"
      assert Enum.at(cumulative_percentages, 0)["percent"] == 10
      assert Enum.at(cumulative_percentages, 1)["date"] == "2016-01-02"
      assert Enum.at(cumulative_percentages, 1)["percent"] == 10
      assert data["total_respondents"] == 15
      assert data["completion_percentage"] == 20
    end

    test "fills dates when any respondent completed the survey with 0's", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)
      survey = insert(:survey, project: project, cutoff: 10, started_at: t)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      insert_list(10, :respondent, survey: survey, state: "pending")
      insert(:respondent, survey: survey, questionnaire: questionnaire, state: "completed", disposition: "completed", updated_at: Ecto.DateTime.cast!("2016-01-03T10:00:00Z"))

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      date_with_no_respondents =
        json_response(conn, 200)["data"]["cumulative_percentages"]
        |> Map.get(to_string(questionnaire.id))
        |> Enum.at(1)

      assert date_with_no_respondents["date"] == "2016-01-02"
      assert date_with_no_respondents["percent"] == 0
    end

    test "target_value field equals respondents count when cutoff is not defined", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      survey = insert(:survey, project: project)
      insert_list(5, :respondent, survey: survey, state: "pending", disposition: "registered")

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)

      total = 5.0

      assert json_response(conn, 200)["data"] == %{
        "id" => survey.id,
        "respondents_by_disposition" => %{
          "uncontacted" => %{
            "count" => 5,
            "percent" => 100*5/total,
            "detail" => %{
              "registered" => %{"count" => 5, "percent" => 100*5/total, "by_reference" => %{"" => 5}},
              "queued" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "failed" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            },
          },
          "contacted" => %{
            "count" => 0,
            "percent" => 0.0,
            "detail" => %{
              "contacted" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "unresponsive" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            },
          },
          "responsive" => %{
            "count" => 0,
            "percent" => 0.0,
            "detail" => %{
              "started" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "breakoff" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "partial" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "completed" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "ineligible" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "refused" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
              "rejected" => %{"count" => 0, "percent" => 0.0, "by_reference" => %{}},
            },
          },
        },
        "cumulative_percentages" => %{},
        "total_respondents" => 5,
        "contacted_respondents" => 0,
        "completion_percentage" => 0,
        "reference" => []
      }
    end

    test "download results csv", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule(), mode: [["sms", "ivr"], ["mobileweb"], ["sms", "mobileweb"]])
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"], stats: %Stats{total_received_sms: 4, total_sent_sms: 3, total_call_time: 12})
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"], stats: %Stats{total_sent_sms: 1})
      insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "csv"})
      csv = response(conn, 200)

      [line1, line2, line3, _] = csv |> String.split("\r\n")
      assert line1 == "Respondent ID,Date,Modes,Smokes,Exercises,Perfect Number,Question,Disposition,Total sent SMS,Total received SMS,Total call time"

      [line_2_hashed_number, _, line_2_modes, line_2_smoke, line_2_exercises, _, _, line_2_disp, line_2_total_sent_sms, line_2_total_received_sms, line_2_total_call_time] = [line2] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd

      assert line_2_hashed_number == respondent_1.hashed_number
      assert line_2_modes == "SMS, Phone call"
      assert line_2_smoke == "Yes"
      assert line_2_exercises == "No"
      assert line_2_disp == "Partial"
      assert line_2_total_sent_sms == "3"
      assert line_2_total_received_sms == "4"
      assert line_2_total_call_time == "12"

      [line_3_hashed_number, _, line_3_modes, line_3_smoke, line_3_exercises, _, _, line_3_disp, line_3_total_sent_sms, line_3_total_received_sms, line_3_total_call_time] = [line3]  |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd
      assert line_3_hashed_number == respondent_2.hashed_number
      assert line_3_modes == "Mobile Web"
      assert line_3_smoke == "No"
      assert line_3_exercises == ""
      assert line_3_disp == "Registered"
      assert line_3_total_sent_sms == "1"
      assert line_3_total_received_sms == "0"
      assert line_3_total_call_time == "0"
    end

    test "download results csv with filter by disposition", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"])
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"])
      insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "csv", "disposition" => "registered"})
      csv = response(conn, 200)

      [line1, line2, _] = csv |> String.split("\r\n")
      assert line1 == "Respondent ID,Date,Modes,Smokes,Exercises,Perfect Number,Question,Disposition,Total sent SMS,Total received SMS"

      [line_2_hashed_number, _, line_2_modes, line_2_smoke, line_2_exercises, _, _, line_2_disp, _, _] = [line2] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd

      assert line_2_hashed_number == respondent_2.hashed_number
      assert line_2_modes == "Mobile Web"
      assert line_2_smoke == "No"
      assert line_2_exercises == ""
      assert line_2_disp == "Registered"
    end

    test "download results csv with filter by update timestamp", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"])
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"], updated_at: Timex.shift(Timex.now, hours: 2, minutes: 3))
      insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "csv", "since" => Timex.format!(Timex.shift(Timex.now, hours: 2), "%FT%T%:z", :strftime)})
      csv = response(conn, 200)

      [line1, line2, _] = csv |> String.split("\r\n")
      assert line1 == "Respondent ID,Date,Modes,Smokes,Exercises,Perfect Number,Question,Disposition,Total sent SMS,Total received SMS"

      [line_2_hashed_number, _, line_2_modes, line_2_smoke, line_2_exercises, _, _, line_2_disp, _, _] = [line2] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd

      assert line_2_hashed_number == respondent_2.hashed_number
      assert line_2_modes == "Mobile Web"
      assert line_2_smoke == "No"
      assert line_2_exercises == ""
      assert line_2_disp == "Registered"
    end

    test "download results csv with filter by final state", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"], state: "completed")
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"])
      insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "csv", "final" => true})
      csv = response(conn, 200)

      [line1, line2, _] = csv |> String.split("\r\n")
      assert line1 == "Respondent ID,Date,Modes,Smokes,Exercises,Perfect Number,Question,Disposition,Total sent SMS,Total received SMS"

      [line_2_hashed_number, _, line_2_modes, line_2_smoke, line_2_exercises, _, _, line_2_disp, _, _] = [line2] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd

      assert line_2_hashed_number == respondent_1.hashed_number
      assert line_2_modes == "SMS, Phone call"
      assert line_2_smoke == "Yes"
      assert line_2_exercises == "No"
      assert line_2_disp == "Partial"
    end

    test "download results json", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"], questionnaire_id: questionnaire.id)
      respondent_1 = Repo.get(Respondent, respondent_1.id)
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      response_1 = insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      response_1 = Repo.get(Response, response_1.id)
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"], questionnaire_id: questionnaire.id)
      respondent_2 = Repo.get(Respondent, respondent_2.id)
      response_2 = insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")
      response_2 = Repo.get(Response, response_2.id)

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "json"})
      assert json_response(conn, 200)["data"]["respondents"] == [
        %{
          "id" => respondent_1.id,
          "phone_number" => respondent_1.hashed_number,
          "survey_id" => survey.id,
          "mode" => nil,
          "effective_modes" => ["sms", "ivr"],
          "questionnaire_id" => questionnaire.id,
          "disposition" => "partial",
          "date" => DateTime.to_iso8601(response_1.updated_at),
          "updated_at" => NaiveDateTime.to_iso8601(respondent_1.updated_at),
          "responses" => [
            %{
              "value" => "Yes",
              "name" => "Smokes"
            },
            %{
              "value" => "No",
              "name" => "Exercises"
            }
          ]
        },
        %{
          "id" => respondent_2.id,
          "phone_number" => respondent_2.hashed_number,
          "survey_id" => survey.id,
          "mode" => nil,
          "effective_modes" => ["mobileweb"],
          "questionnaire_id" => questionnaire.id,
          "disposition" => "registered",
          "date" => DateTime.to_iso8601(response_2.updated_at),
          "updated_at" => NaiveDateTime.to_iso8601(respondent_2.updated_at),
          "responses" => [
            %{
              "value" => "No",
              "name" => "Smokes"
            }
          ]
        }
      ]
    end

    test "download results json with filter by disposition", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"], questionnaire_id: questionnaire.id)
      respondent_1 = Repo.get(Respondent, respondent_1.id)
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      response_1 = insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      response_1 = Repo.get(Response, response_1.id)
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"], questionnaire_id: questionnaire.id)
      respondent_2 = Repo.get(Respondent, respondent_2.id)
      insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "json", "disposition" => "partial"})
      assert json_response(conn, 200)["data"]["respondents"] == [
        %{
           "id" => respondent_1.id,
           "phone_number" => respondent_1.hashed_number,
           "survey_id" => survey.id,
           "mode" => nil,
           "effective_modes" => ["sms", "ivr"],
           "questionnaire_id" => questionnaire.id,
           "disposition" => "partial",
           "date" => DateTime.to_iso8601(response_1.updated_at),
           "updated_at" => NaiveDateTime.to_iso8601(respondent_1.updated_at),
           "responses" => [
             %{
               "value" => "Yes",
               "name" => "Smokes"
             },
             %{
               "value" => "No",
               "name" => "Exercises"
             }
           ]
        }
      ]
    end

    test "download results json with filter by update timestamp", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"], questionnaire_id: questionnaire.id)
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"], questionnaire_id: questionnaire.id, updated_at: Timex.shift(Timex.now, hours: 2, minutes: 3))
      respondent_2 = Repo.get(Respondent, respondent_2.id)
      response_2 = insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")
      response_2 = Repo.get(Response, response_2.id)

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "json", "since" => Timex.format!(Timex.shift(Timex.now, hours: 2), "%FT%T%:z", :strftime)})
      assert json_response(conn, 200)["data"]["respondents"] == [
        %{
           "id" => respondent_2.id,
           "phone_number" => respondent_2.hashed_number,
           "survey_id" => survey.id,
           "mode" => nil,
           "effective_modes" => ["mobileweb"],
           "questionnaire_id" => questionnaire.id,
           "disposition" => "registered",
           "date" => DateTime.to_iso8601(response_2.updated_at),
           "updated_at" => NaiveDateTime.to_iso8601(respondent_2.updated_at),
           "responses" => [
             %{
               "value" => "No",
               "name" => "Smokes"
             }
           ]
        }
      ]
    end

    test "download results json with filter by final state", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"], questionnaire_id: questionnaire.id)
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"], questionnaire_id: questionnaire.id, state: "completed")
      respondent_2 = Repo.get(Respondent, respondent_2.id)
      response_2 = insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")
      response_2 = Repo.get(Response, response_2.id)

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "json", "final" => true})
      assert json_response(conn, 200)["data"]["respondents"] == [
        %{
           "id" => respondent_2.id,
           "phone_number" => respondent_2.hashed_number,
           "survey_id" => survey.id,
           "mode" => nil,
           "effective_modes" => ["mobileweb"],
           "questionnaire_id" => questionnaire.id,
           "disposition" => "registered",
           "date" => DateTime.to_iso8601(response_2.updated_at),
           "updated_at" => NaiveDateTime.to_iso8601(respondent_2.updated_at),
           "responses" => [
             %{
               "value" => "No",
               "name" => "Smokes"
             }
           ]
        }
      ]
    end

    test "download results csv with comparisons", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      questionnaire2 = insert(:questionnaire, name: "test 2", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire, questionnaire2], state: "ready", schedule: completed_schedule(),
        comparisons: [
          %{"mode" => ["sms"], "questionnaire_id" => questionnaire.id, "ratio" => 50},
          %{"mode" => ["sms"], "questionnaire_id" => questionnaire2.id, "ratio" => 50},
        ]
      )
      respondent_1 = insert(:respondent, survey: survey, questionnaire_id: questionnaire.id, mode: ["sms"], disposition: "partial")
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Perfect Number", value: "No")
      respondent_2 = insert(:respondent, survey: survey, questionnaire_id: questionnaire2.id, mode: ["sms", "ivr"], disposition: "completed")
      insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "csv"})
      csv = response(conn, 200)

      [line1, line2, line3, _] = csv |> String.split("\r\n")
      assert line1 == "Respondent ID,Date,Modes,Smokes,Exercises,Perfect Number,Question,Variant,Disposition,Total sent SMS,Total received SMS"

      [line_2_hashed_number, _, _, line_2_smoke, _, line_2_number, _, line_2_variant, line_2_disp, _, _] = [line2] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd
      assert line_2_hashed_number == respondent_1.hashed_number |> to_string
      assert line_2_smoke == "Yes"
      assert line_2_number == "No"
      assert line_2_variant == "test - SMS"
      assert line_2_disp == "Partial"

      [line_3_hashed_number, _, _, line_3_smoke, _, line_3_number, _, line_3_variant, line_3_disp, _, _] = [line3] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd
      assert line_3_hashed_number == respondent_2.hashed_number |> to_string
      assert line_3_smoke == "No"
      assert line_3_number == ""
      assert line_3_variant == "test 2 - SMS with phone call fallback"
      assert line_3_disp == "Completed"
    end

    test "download results json with comparisons", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      questionnaire2 = insert(:questionnaire, name: "test 2", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire, questionnaire2], state: "ready", schedule: completed_schedule(),
        comparisons: [
          %{"mode" => ["sms"], "questionnaire_id" => questionnaire.id, "ratio" => 50},
          %{"mode" => ["sms"], "questionnaire_id" => questionnaire2.id, "ratio" => 50},
        ]
      )

      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"], mode: ["sms"], questionnaire_id: questionnaire.id)
      respondent_1 = Repo.get(Respondent, respondent_1.id)
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      response_1 = insert(:response, respondent: respondent_1, field_name: "Perfect Number", value: "No")
      response_1 = Repo.get(Response, response_1.id)

      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"], mode: ["sms", "ivr"], questionnaire_id: questionnaire2.id, disposition: "completed")
      respondent_2 = Repo.get(Respondent, respondent_2.id)
      response_2 = insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")
      response_2 = Repo.get(Response, response_2.id)

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "json"})
      assert json_response(conn, 200)["data"]["respondents"] == [
        %{
           "id" => respondent_1.id,
           "phone_number" => respondent_1.hashed_number,
           "survey_id" => survey.id,
           "mode" => ["sms"],
           "effective_modes" =>["sms", "ivr"],
           "questionnaire_id" => questionnaire.id,
           "disposition" => "partial",
           "date" => DateTime.to_iso8601(response_1.updated_at),
           "updated_at" => NaiveDateTime.to_iso8601(respondent_1.updated_at),
           "experiment_name" => "test - SMS",
           "responses" => [
             %{
               "value" => "Yes",
               "name" => "Smokes"
             },
             %{
               "value" => "No",
               "name" => "Perfect Number"
             }
           ]
        },
        %{
           "id" => respondent_2.id,
           "phone_number" => respondent_2.hashed_number,
           "survey_id" => survey.id,
           "mode" => ["sms", "ivr"],
           "effective_modes" =>["mobileweb"],
           "questionnaire_id" => questionnaire2.id,
           "experiment_name" => "test 2 - SMS with phone call fallback",
           "disposition" => "completed",
           "date" => DateTime.to_iso8601(response_2.updated_at),
           "updated_at" => NaiveDateTime.to_iso8601(respondent_2.updated_at),
           "responses" => [
             %{
               "value" => "No",
               "name" => "Smokes"
             }
           ]
        }
      ]
    end

    test "download csv with language", %{conn: conn, user: user} do
      languageStep = %{
        "id" => "1234-5678",
        "type" => "language-selection",
        "title" => "Language selection",
        "store" => "language",
        "prompt" => %{
          "sms" => "1 for English, 2 for Spanish",
          "ivr" => %{
            "text" => "1 para ingles, 2 para español",
            "audioSource" => "tts",
          }
        },
        "language_choices" => ["en", "es"],
      }
      steps = [languageStep]

      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial")
      insert(:response, respondent: respondent_1, field_name: "language", value: "es")

      conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "csv"})
      csv = response(conn, 200)

      [line1, line2, _] = csv |> String.split("\r\n")
      assert line1 == "Respondent ID,Date,Modes,language,Disposition,Total sent SMS,Total received SMS"

      [line_2_hashed_number, _, _, line_2_language, _, _, _] = [line2] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd
      assert line_2_hashed_number == respondent_1.hashed_number
      assert line_2_language == "español"
    end

    test "download disposition history csv", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet")

      insert(:respondent_disposition_history, respondent: respondent_1, disposition: "partial", mode: "sms", inserted_at: Ecto.DateTime.cast!("2000-01-01 01:02:03"))
      insert(:respondent_disposition_history, respondent: respondent_1, disposition: "completed",  mode: "sms",inserted_at: Ecto.DateTime.cast!("2000-01-01 02:03:04"))

      insert(:respondent_disposition_history, respondent: respondent_2, disposition: "partial", mode: "ivr", inserted_at: Ecto.DateTime.cast!("2000-01-01 03:04:05"))
      insert(:respondent_disposition_history, respondent: respondent_2, disposition: "completed", mode: "ivr", inserted_at: Ecto.DateTime.cast!("2000-01-01 04:05:06"))

      conn = get conn, project_survey_respondents_disposition_history_path(conn, :disposition_history, survey.project.id, survey.id, %{"_format" => "csv"})
      csv = response(conn, 200)

      lines = csv |> String.split("\r\n") |> Enum.reject(fn x -> String.length(x) == 0 end)
      assert lines == ["Respondent ID,Disposition,Mode,Timestamp",
       "1asd12451eds,partial,SMS,2000-01-01 01:02:03 UTC",
       "1asd12451eds,completed,SMS,2000-01-01 02:03:04 UTC",
       "34y5345tjyet,partial,Phone call,2000-01-01 03:04:05 UTC",
       "34y5345tjyet,completed,Phone call,2000-01-01 04:05:06 UTC"]
    end

    test "download incentives", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      insert(:respondent, survey: survey, phone_number: "1234", disposition: "partial", questionnaire_id: questionnaire.id, mode: ["sms"])
      insert(:respondent, survey: survey, phone_number: "5678", disposition: "completed", questionnaire_id: questionnaire.id, mode: ["sms", "ivr"])
      insert(:respondent, survey: survey, phone_number: "9012", disposition: "completed", mode: ["sms", "ivr"])

      conn = get conn, project_survey_respondents_incentives_path(conn, :incentives, survey.project.id, survey.id, %{"_format" => "csv"})
      csv = response(conn, 200)

      lines = csv |> String.split("\r\n") |> Enum.reject(fn x -> String.length(x) == 0 end)
      assert lines == [
        "Telephone number,Questionnaire-Mode",
        "5678,test - SMS with phone call fallback"
      ]
    end

    test "download interactions", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1234")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "5678")
      channel = insert(:channel, name: "test_channel")
      for _ <- 1..200 do
        insert(:survey_log_entry, survey: survey, mode: "sms",respondent: respondent_1, respondent_hashed_number: "5678", channel: channel, disposition: "completed", action_type: "prompt", action_data: "explanation", timestamp: Ecto.DateTime.cast!("2000-01-01 01:02:03"))
        insert(:survey_log_entry, survey: survey, mode: "ivr",respondent: respondent_2, respondent_hashed_number: "1234", channel: nil, disposition: "partial", action_type: "contact", action_data: "explanation", timestamp: Ecto.DateTime.cast!("2000-01-01 02:03:04"))
        insert(:survey_log_entry, survey: survey, mode: "mobileweb",respondent: respondent_2, respondent_hashed_number: "5678", channel: nil, disposition: "partial", action_type: "contact", action_data: "explanation", timestamp: Ecto.DateTime.cast!("2000-01-01 03:04:05"))
      end

      conn = get conn, project_survey_respondents_interactions_path(conn, :interactions, survey.project.id, survey.id, %{"_format" => "csv"})
      csv = response(conn, 200)

      expected_list = List.flatten(
        ["Respondent ID,Mode,Channel,Disposition,Action Type,Action Data,Timestamp",
        for _ <- 1..200 do
          "1234,IVR,,Partial,Contact attempt,explanation,2000-01-01 02:03:04 UTC"
        end,
        for _ <- 1..200 do
          ["5678,SMS,test_channel,Completed,Prompt,explanation,2000-01-01 01:02:03 UTC",
          "5678,Mobile Web,,Partial,Contact attempt,explanation,2000-01-01 03:04:05 UTC"]
        end,
      ])
      lines = csv |> String.split("\r\n") |> Enum.reject(fn x -> String.length(x) == 0 end)
      assert length(lines) == length(expected_list)
      assert lines == expected_list
    end

    test "quotas_stats", %{conn: conn, user: user} do
      t = Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}")
      project = create_project_for_user(user)

      quotas = %{
        "vars" => ["Smokes", "Exercises"],
        "buckets" => [
          %{
            "condition" => [%{"store" => "Smokes", "value" => "No"}, %{"store" => "Exercises", "value" => "No"}],
            "quota" => 1,
            "count" => 1
          },
          %{
            "condition" => [%{"store" => "Smokes", "value" => "No"}, %{"store" => "Exercises", "value" => "Yes"}],
            "quota" => 4,
            "count" => 2
          },
        ]
      }

      survey = insert(:survey, project: project, started_at: t)
      survey = survey
      |> Repo.preload([:quota_buckets])
      |> Survey.changeset(%{quotas: quotas})
      |> Repo.update!

      qb1 = (from q in QuotaBucket, where: q.quota == 1) |> Repo.one
      qb4 = (from q in QuotaBucket, where: q.quota == 4) |> Repo.one

      insert(:respondent, survey: survey, state: "completed", quota_bucket_id: qb1.id, completed_at: Timex.parse!("2016-01-01T10:00:00Z", "{ISO:Extended}"))
      insert(:respondent, survey: survey, state: "completed", quota_bucket_id: qb4.id, completed_at: Timex.parse!("2016-01-01T11:00:00Z", "{ISO:Extended}"))
      insert(:respondent, survey: survey, state: "active", quota_bucket_id: qb4.id, completed_at: Timex.parse!("2016-01-01T11:00:00Z", "{ISO:Extended}"))
      insert(:respondent, survey: survey, state: "active", disposition: "queued")

      conn = get conn, project_survey_respondents_stats_path(conn, :stats, project.id, survey.id)
      assert json_response(conn, 200) == %{ "data" => %{
        "reference" => [
         %{"name" => "Smokes: No - Exercises: No", "id" => qb1.id},
          %{"name" => "Smokes: No - Exercises: Yes", "id" => qb4.id}
        ],
        "completion_percentage" => 0.0,
        "contacted_respondents" => 0,
        "cumulative_percentages" => %{},
        "id" => survey.id,
        "respondents_by_disposition" => %{
          "contacted" => %{
            "count" => 0,
            "detail" => %{
              "contacted" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "unresponsive" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0}
            },
            "percent" => 0.0
          },
          "responsive" => %{
            "count" => 0,
            "detail" => %{
              "breakoff" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "completed" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "ineligible" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "partial" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "refused" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "rejected" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "started" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0}
            },
            "percent" => 0.0
          },
          "uncontacted" => %{
            "count" => 4,
            "detail" => %{
              "failed" => %{"by_reference" => %{}, "count" => 0, "percent" => 0.0},
              "queued" => %{"by_reference" => %{"" => 1}, "count" => 1, "percent" => 25.0},
              "registered" => %{"by_reference" => %{"#{qb1.id}" => 1, "#{qb4.id}" => 2}, "count" => 3, "percent" => 75.0}
            },
            "percent" => 100.0
          }
        },
        "total_respondents" => 4
      }}
    end
  end

  describe "links" do
    setup %{conn: conn} do
      user = insert(:user)
      conn = conn
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user: user}
    end

    test "download results csv using a download link", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project, steps: @dummy_steps)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial", effective_modes: ["sms", "ivr"])
      insert(:response, respondent: respondent_1, field_name: "Smokes", value: "Yes")
      insert(:response, respondent: respondent_1, field_name: "Exercises", value: "No")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet", effective_modes: ["mobileweb"])
      insert(:response, respondent: respondent_2, field_name: "Smokes", value: "No")

      {:ok, link} = ShortLink.generate_link(Survey.link_name(survey, :results), project_survey_respondents_results_path(conn, :results, project, survey, %{"_format" => "csv"}))

      conn = get conn, short_link_path(conn, :access, link.hash)
      # conn = get conn, project_survey_respondents_results_path(conn, :results, survey.project.id, survey.id, %{"offset" => "0", "_format" => "csv"})
      csv = response(conn, 200)

      [line1, line2, line3, _] = csv |> String.split("\r\n")
      assert line1 == "Respondent ID,Date,Modes,Smokes,Exercises,Perfect Number,Question,Disposition,Total sent SMS,Total received SMS"

      [line_2_hashed_number, _, line_2_modes, line_2_smoke, line_2_exercises, _, _, line_2_disp,_ ,_] = [line2] |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd

      assert line_2_hashed_number == respondent_1.hashed_number
      assert line_2_modes == "SMS, Phone call"
      assert line_2_smoke == "Yes"
      assert line_2_exercises == "No"
      assert line_2_disp == "Partial"

      [line_3_hashed_number, _, line_3_modes, line_3_smoke, line_3_exercises, _, _, line_3_disp, _, _] = [line3]  |> Stream.map(&(&1)) |> CSV.decode |> Enum.to_list |> hd
      assert line_3_hashed_number == respondent_2.hashed_number
      assert line_3_modes == "Mobile Web"
      assert line_3_smoke == "No"
      assert line_3_exercises == ""
      assert line_3_disp == "Registered"
    end

    test "download disposition history using download link", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1asd12451eds", disposition: "partial")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "34y5345tjyet")

      insert(:respondent_disposition_history, respondent: respondent_1, disposition: "partial", mode: "sms", inserted_at: Ecto.DateTime.cast!("2000-01-01 01:02:03"))
      insert(:respondent_disposition_history, respondent: respondent_1, disposition: "completed",  mode: "sms",inserted_at: Ecto.DateTime.cast!("2000-01-01 02:03:04"))

      insert(:respondent_disposition_history, respondent: respondent_2, disposition: "partial", mode: "ivr", inserted_at: Ecto.DateTime.cast!("2000-01-01 03:04:05"))
      insert(:respondent_disposition_history, respondent: respondent_2, disposition: "completed", mode: "ivr", inserted_at: Ecto.DateTime.cast!("2000-01-01 04:05:06"))

      {:ok, link} = ShortLink.generate_link(Survey.link_name(survey, :results), project_survey_respondents_disposition_history_path(conn, :disposition_history, project, survey, %{"_format" => "csv"}))

      conn = get conn, short_link_path(conn, :access, link.hash)
      # conn = get conn, project_survey_respondents_disposition_history_path(conn, :disposition_history, survey.project.id, survey.id, %{"_format" => "csv"})
      csv = response(conn, 200)

      lines = csv |> String.split("\r\n") |> Enum.reject(fn x -> String.length(x) == 0 end)
      assert lines == ["Respondent ID,Disposition,Mode,Timestamp",
       "1asd12451eds,partial,SMS,2000-01-01 01:02:03 UTC",
       "1asd12451eds,completed,SMS,2000-01-01 02:03:04 UTC",
       "34y5345tjyet,partial,Phone call,2000-01-01 03:04:05 UTC",
       "34y5345tjyet,completed,Phone call,2000-01-01 04:05:06 UTC"]
    end

    test "download incentives using download link", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      insert(:respondent, survey: survey, phone_number: "1234", disposition: "partial", questionnaire_id: questionnaire.id, mode: ["sms"])
      insert(:respondent, survey: survey, phone_number: "5678", disposition: "completed", questionnaire_id: questionnaire.id, mode: ["sms", "ivr"])
      insert(:respondent, survey: survey, phone_number: "9012", disposition: "completed", mode: ["sms", "ivr"])

      {:ok, link} = ShortLink.generate_link(Survey.link_name(survey, :results), project_survey_respondents_incentives_path(conn, :incentives, project, survey, %{"_format" => "csv"}))

      conn = get conn, short_link_path(conn, :access, link.hash)
      # conn = get conn, project_survey_respondents_incentives_path(conn, :incentives, survey.project.id, survey.id, %{"_format" => "csv"})
      csv = response(conn, 200)

      lines = csv |> String.split("\r\n") |> Enum.reject(fn x -> String.length(x) == 0 end)
      assert lines == [
        "Telephone number,Questionnaire-Mode",
        "5678,test - SMS with phone call fallback"
      ]
    end

    test "download interactions using download link", %{conn: conn, user: user} do
      project = create_project_for_user(user)
      questionnaire = insert(:questionnaire, name: "test", project: project)
      survey = insert(:survey, project: project, cutoff: 4, questionnaires: [questionnaire], state: "ready", schedule: completed_schedule())
      respondent_1 = insert(:respondent, survey: survey, hashed_number: "1234")
      respondent_2 = insert(:respondent, survey: survey, hashed_number: "5678")
      channel = insert(:channel, name: "test_channel")
      for _ <- 1..200 do
        insert(:survey_log_entry, survey: survey, mode: "sms",respondent: respondent_1, respondent_hashed_number: "5678", channel: channel, disposition: "completed", action_type: "prompt", action_data: "explanation", timestamp: Ecto.DateTime.cast!("2000-01-01 01:02:03"))
        insert(:survey_log_entry, survey: survey, mode: "ivr",respondent: respondent_2, respondent_hashed_number: "1234", channel: nil, disposition: "partial", action_type: "contact", action_data: "explanation", timestamp: Ecto.DateTime.cast!("2000-01-01 02:03:04"))
        insert(:survey_log_entry, survey: survey, mode: "mobileweb",respondent: respondent_2, respondent_hashed_number: "5678", channel: nil, disposition: "partial", action_type: "contact", action_data: "explanation", timestamp: Ecto.DateTime.cast!("2000-01-01 03:04:05"))
      end

      {:ok, link} = ShortLink.generate_link(Survey.link_name(survey, :results), project_survey_respondents_interactions_path(conn, :interactions, project, survey, %{"_format" => "csv"}))

      conn = get conn, short_link_path(conn, :access, link.hash)
      # conn = get conn, project_survey_respondents_interactions_path(conn, :interactions, survey.project.id, survey.id, %{"_format" => "csv"})
      csv = response(conn, 200)

      expected_list = List.flatten(
        ["Respondent ID,Mode,Channel,Disposition,Action Type,Action Data,Timestamp",
        for _ <- 1..200 do
          "1234,IVR,,Partial,Contact attempt,explanation,2000-01-01 02:03:04 UTC"
        end,
        for _ <- 1..200 do
          ["5678,SMS,test_channel,Completed,Prompt,explanation,2000-01-01 01:02:03 UTC",
          "5678,Mobile Web,,Partial,Contact attempt,explanation,2000-01-01 03:04:05 UTC"]
        end,
      ])
      lines = csv |> String.split("\r\n") |> Enum.reject(fn x -> String.length(x) == 0 end)
      assert length(lines) == length(expected_list)
      assert lines == expected_list
    end

  end

  def completed_schedule() do
    Ask.Schedule.always()
  end
end
