defmodule Ask.RespondentControllerTest do
  use Ask.ConnCase
  alias Ask.Respondent

  @valid_attrs %{phone_number: "some content"}
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    project = insert(:project)
    survey = insert(:survey, project: project)
    conn = get conn, project_survey_respondent_path(conn, :index, project.id, survey.id)
    assert json_response(conn, 200)["data"] == []
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    project = insert(:project)
    survey = insert(:survey, project: project)

    file = %Plug.Upload{path: "test/fixtures/respondent_phone_numbers.csv", filename: "phone_numbers.csv"}

    conn = post conn, project_survey_respondent_path(conn, :create, project.id, survey.id), file: file
    assert length(json_response(conn, 201)["data"]) == 14

    all = Repo.all(from r in Respondent, where: r.survey_id == ^survey.id)
    assert length(all) == 14
    assert Enum.at(all, 0).survey_id == survey.id
    assert Enum.at(all, 0).phone_number == "(549) 11 4234 2343"
  end
end
