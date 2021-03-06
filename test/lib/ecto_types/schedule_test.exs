defmodule Ask.ScheduleTest do
  use Ask.ModelCase
  alias Ask.{Schedule, DayOfWeek}

  @default_schedule Schedule.default()

  test "always" do
    assert %Schedule{day_of_week: %DayOfWeek{sun: true, mon: true, tue: true, wed: true, thu: true, fri: true, sat: true}, start_time: ~T[00:00:00], end_time: ~T[23:59:59], blocked_days: [], timezone: "Etc/UTC"} == Schedule.always()
  end

  test "default" do
    assert %Schedule{day_of_week: %DayOfWeek{}, start_time: ~T[09:00:00], end_time: ~T[18:00:00], blocked_days: [], timezone: "Etc/UTC"} == Schedule.default()
  end

  describe "dump:" do
    test "should dump weekdays" do
      assert {:ok, "{\"timezone\":\"Etc/UTC\",\"start_time\":\"09:00:00\",\"end_time\":\"18:00:00\",\"day_of_week\":[\"mon\",\"tue\",\"wed\",\"thu\",\"fri\"],\"blocked_days\":[]}"} == Schedule.dump(%Schedule{day_of_week: %DayOfWeek{mon: true, tue: true, wed: true, thu: true, fri: true}, start_time: ~T[09:00:00], end_time: ~T[18:00:00], timezone: Schedule.default_timezone()})
    end

    test "should dump default" do
      assert {:ok, "{\"timezone\":\"Etc/UTC\",\"start_time\":\"09:00:00\",\"end_time\":\"18:00:00\",\"day_of_week\":[],\"blocked_days\":[]}"} == Schedule.dump(Schedule.default())
    end

    test "should dump always" do
      assert {:ok, "{\"timezone\":\"Etc/UTC\",\"start_time\":\"00:00:00\",\"end_time\":\"23:59:59\",\"day_of_week\":[\"sun\",\"mon\",\"tue\",\"wed\",\"thu\",\"fri\",\"sat\"],\"blocked_days\":[]}"} == Schedule.dump(Schedule.always())
    end

    test "should dump blocked_days" do
      assert {:ok, "{\"timezone\":\"Etc/UTC\",\"start_time\":\"09:00:00\",\"end_time\":\"18:00:00\",\"day_of_week\":[\"mon\",\"tue\",\"wed\",\"thu\",\"fri\"],\"blocked_days\":[\"2016-01-01\",\"2017-02-03\"]}"} == Schedule.dump(%Schedule{day_of_week: %DayOfWeek{mon: true, tue: true, wed: true, thu: true, fri: true}, start_time: ~T[09:00:00], end_time: ~T[18:00:00], timezone: Schedule.default_timezone(), blocked_days: [~D[2016-01-01], ~D[2017-02-03]]})
    end
  end

  describe "load:" do
    test "should load weekdays" do
      assert {:ok, %Schedule{day_of_week: %DayOfWeek{mon: true, tue: true, wed: true, thu: true, fri: true, sun: false, sat: false}, start_time: ~T[09:00:00], end_time: ~T[18:00:00], blocked_days: [], timezone: "America/Argentina/Buenos_Aires"}} == Schedule.load("{\"timezone\":\"America/Argentina/Buenos_Aires\",\"start_time\":\"09:00:00\",\"end_time\":\"18:00:00\",\"day_of_week\":[\"mon\",\"tue\",\"wed\",\"thu\",\"fri\"],\"blocked_days\":[]}")
    end

    test "should load blocked_days" do
      assert {:ok, %Schedule{day_of_week: %DayOfWeek{mon: true, tue: true, wed: true, thu: true, fri: true, sun: false, sat: false}, start_time: ~T[09:00:00], end_time: ~T[18:00:00], blocked_days: [~D[2016-01-01], ~D[2017-02-03]], timezone: "America/Argentina/Buenos_Aires"}} == Schedule.load("{\"timezone\":\"America/Argentina/Buenos_Aires\",\"start_time\":\"09:00:00\",\"end_time\":\"18:00:00\",\"day_of_week\":[\"mon\",\"tue\",\"wed\",\"thu\",\"fri\"],\"blocked_days\":[\"2016-01-01\",\"2017-02-03\"]}")
    end
  end

  describe "cast:" do
    test "shuld cast to itself" do
      assert {:ok, %Schedule{day_of_week: %DayOfWeek{}, start_time: ~T[09:00:00], end_time: ~T[18:00:00], blocked_days: [], timezone: "Etc/UTC"}} == Schedule.cast(Schedule.default())
    end

    test "should cast string times" do
      assert {
        :ok,
        %Schedule{day_of_week: %DayOfWeek{sun: true, mon: true, tue: true, wed: true, thu: true, fri: false, sat: true}, start_time: ~T[09:00:00], end_time: ~T[19:00:00], blocked_days: [], timezone: "Etc/UTC"}
      } == Schedule.cast(%{day_of_week: %{sun: true, mon: true, tue: true, wed: true, thu: true, fri: false, sat: true}, start_time: "09:00:00", end_time: "19:00:00", timezone: "Etc/UTC", blocked_days: []})
    end

    test "should cast string days" do
      assert {
        :ok,
        %Schedule{day_of_week: %DayOfWeek{sun: true, mon: true, tue: true, wed: true, thu: true, fri: false, sat: true}, start_time: ~T[09:00:00], end_time: ~T[19:00:00], blocked_days: [~D[2016-01-01], ~D[2017-02-03]], timezone: "Etc/UTC"}
      } == Schedule.cast(%{day_of_week: %{sun: true, mon: true, tue: true, wed: true, thu: true, fri: false, sat: true}, start_time: ~T[09:00:00], end_time: "19:00:00", timezone: "Etc/UTC", blocked_days: ["2016-01-01", "2017-02-03"]})
    end

    test "should cast string times with string keys" do
      assert {
        :ok,
        %Schedule{day_of_week: %DayOfWeek{sun: true, mon: true, tue: true, wed: true, thu: true, fri: false, sat: true}, start_time: ~T[09:00:00], end_time: ~T[19:00:00], blocked_days: [], timezone: "Etc/UTC"}
      } == Schedule.cast(%{"day_of_week" => %{"sun" => true, "mon" => true, "tue" => true, "wed" => true, "thu" => true, "fri" => false, "sat" => true}, "start_time" => "09:00:00", "end_time" => "19:00:00", "timezone" => "Etc/UTC"})
    end

    test "should cast string days with string keys" do
      assert {
        :ok,
        %Schedule{day_of_week: %DayOfWeek{sun: true, mon: true, tue: true, wed: true, thu: true, fri: false, sat: true}, start_time: ~T[09:00:00], end_time: ~T[19:00:00], blocked_days: [~D[2016-01-01], ~D[2017-02-03]], timezone: "Etc/UTC"}
      } == Schedule.cast(%{"day_of_week" => %{"sun" => true, "mon" => true, "tue" => true, "wed" => true, "thu" => true, "fri" => false, "sat" => true}, "start_time" => "09:00:00", "end_time" => ~T[19:00:00], "timezone" => "Etc/UTC", "blocked_days" => ["2016-01-01", "2017-02-03"]})
    end

    test "shuld cast a struct with string keys" do
      assert {
        :ok,
        %Schedule{day_of_week: %DayOfWeek{sun: true, mon: true, tue: true, wed: true, thu: true, fri: false, sat: true}, start_time: ~T[09:00:00], end_time: ~T[19:00:00], blocked_days: []}
      } == Schedule.cast(%{"day_of_week" => %{"sun" => true, "mon" => true, "tue" => true, "wed" => true, "thu" => true, "fri" => false, "sat" => true}, "start_time" => ~T[09:00:00], "end_time" => ~T[19:00:00]})
    end

    test "shuld cast nil" do
      assert {:ok, @default_schedule} == Schedule.cast(nil)
    end
  end

  describe "next_available_date_time" do
    @schedule %Ask.Schedule{
      start_time: ~T[09:00:00],
      end_time: ~T[18:00:00],
      day_of_week: %Ask.DayOfWeek{sun: true, wed: true},
      timezone: "America/Argentina/Buenos_Aires",
      blocked_days: [~D[2017-10-08]]
    }

    test "gets next available time: free slot" do
      # OK because 20hs UTC is 17hs GMT-03
      base = DateTime.from_naive!(~N[2017-03-05 20:00:00], "Etc/UTC")
      time = @schedule |> Schedule.next_available_date_time(base)
      assert time == base
    end

    test "gets next available time: this day, earlier" do
      # 9hs UTC is 6hs GMT-03
      base = DateTime.from_naive!(~N[2017-03-05 09:00:00], "Etc/UTC")
      time = @schedule |> Schedule.next_available_date_time(base)
      # 12hs UTC is 9hs GMT-03
      assert time == DateTime.from_naive!(~N[2017-03-05 12:00:00], "Etc/UTC")
    end

    test "gets next available time: this day, too late" do
      # 9hs UTC is 6hs GMT-03
      base = DateTime.from_naive!(~N[2017-03-05 22:00:00], "Etc/UTC")
      time = @schedule |> Schedule.next_available_date_time(base)
      # Next available day is Wednesday
      assert time == DateTime.from_naive!(~N[2017-03-08 12:00:00], "Etc/UTC")
    end

    test "gets next available time: unavaible day" do
      base = DateTime.from_naive!(~N[2017-03-06 15:00:00], "Etc/UTC")
      time = @schedule |> Schedule.next_available_date_time(base)
      assert time == DateTime.from_naive!(~N[2017-03-08 12:00:00], "Etc/UTC")
    end

    test "gets next available time: blocked day" do
      base = DateTime.from_naive!(~N[2017-10-08 13:00:00], "Etc/UTC")
      time = @schedule |> Schedule.next_available_date_time(base)
      assert time == DateTime.from_naive!(~N[2017-10-11 12:00:00], "Etc/UTC")
    end
  end
end
