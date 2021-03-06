defmodule Ask.Runtime.NuntiumChannelTest do
  use Ask.ConnCase
  use Ask.DummySteps

  alias Ask.{Respondent, BrokerStub}
  alias Ask.Runtime.{NuntiumChannel, ReplyHelper}

  require Ask.Runtime.ReplyHelper

  setup %{conn: conn} do
    GenServer.start_link(BrokerStub, [], name: BrokerStub.server_ref)
    respondent = insert(:respondent, phone_number: "123 456", sanitized_phone_number: "123456", state: "active")
    {:ok, conn: conn, respondent: respondent}
  end

  test "callback with :prompts", %{conn: conn, respondent: respondent} do
    respondent_id = respondent.id
    GenServer.cast(BrokerStub.server_ref, {:expects, fn
      {:sync_step, %Respondent{id: ^respondent_id}, {:reply, "yes"}, "sms"} ->
        {:reply, ReplyHelper.multiple(["Hello!", "Do you exercise?"])}
    end})
    conn = NuntiumChannel.callback(conn, %{"channel" => "chan1", "from" => "sms://123456", "body" => "yes"}, BrokerStub)
    assert [%{"to" => "sms://123456", "body" => "Hello!", "step_title" => "Hello!"}, %{"to" => "sms://123456", "body" => "Do you exercise?", "step_title" => "Do you exercise?"}] = json_response(conn, 200)

    assert Repo.get(Respondent, respondent.id).stats == %Ask.Stats{
      total_received_sms: 1,
      total_sent_sms: 2
    }
  end

  test "callback with :end", %{conn: conn, respondent: respondent} do
    respondent_id = respondent.id
    GenServer.cast(BrokerStub.server_ref, {:expects, fn
      {:sync_step, %Respondent{id: ^respondent_id}, {:reply, "yes"}, "sms"} ->
        :end
    end})
    conn = NuntiumChannel.callback(conn, %{"channel" => "chan1", "from" => "sms://123456", "body" => "yes"}, BrokerStub)
    assert json_response(conn, 200) == []

    assert Repo.get(Respondent, respondent.id).stats == %Ask.Stats{
      total_received_sms: 1,
      total_sent_sms: 0
    }
  end

  test "callback with :end, :prompt", %{conn: conn, respondent: respondent} do
    respondent_id = respondent.id
    GenServer.cast(BrokerStub.server_ref, {:expects, fn
      {:sync_step, %Respondent{id: ^respondent_id}, {:reply, "yes"}, "sms"} ->
        {:end, {:reply, ReplyHelper.quota_completed("Bye!")}}
    end})
    conn = NuntiumChannel.callback(conn, %{"channel" => "chan1", "from" => "sms://123456", "body" => "yes"}, BrokerStub)
    assert [%{"body" => "Bye!", "to" => "sms://123456", "step_title" => "Quota completed"}] = json_response(conn, 200)

    assert Repo.get(Respondent, respondent.id).stats == %Ask.Stats{
      total_received_sms: 1,
      total_sent_sms: 1
    }
  end

  test "callback respondent not found", %{conn: conn} do
    conn = NuntiumChannel.callback(conn, %{"channel" => "chan1", "from" => "sms://456", "body" => "yes"}, BrokerStub)
    assert json_response(conn, 200) == []
  end

  test "callback with stalled respondent", %{conn: conn} do
    respondent = insert(:respondent, phone_number: "123 457", sanitized_phone_number: "123457", state: "stalled")
    respondent_id = respondent.id
    GenServer.cast(BrokerStub.server_ref, {:expects, fn
      {:sync_step, %Respondent{id: ^respondent_id}, {:reply, "yes"}, "sms"} ->
        {:reply, ReplyHelper.simple("Do you exercise?")}
    end})
    conn = NuntiumChannel.callback(conn, %{"channel" => "chan1", "from" => "sms://123457", "body" => "yes"}, BrokerStub)
    assert [%{"to" => "sms://123457", "body" => "Do you exercise?", "step_title" => "Do you exercise?"}] = json_response(conn, 200)

    assert Repo.get(Respondent, respondent.id).stats == %Ask.Stats{
      total_received_sms: 1,
      total_sent_sms: 1
    }
  end

  test "unknown callback is replied with OK", %{conn: conn} do
    conn = NuntiumChannel.callback(conn, %{"channel" => "foo", "guid" => Ecto.UUID.generate, "state" => "delivered"})
    assert response(conn, 200) == "OK"
  end

  test "status callback for unknown respondent is replied with OK", %{conn: conn} do
    conn = NuntiumChannel.callback(conn, %{"path" => ["status"], "respondent_id" => "-1", "state" => "delivered"})
    assert response(conn, 200) == ""
  end

  test "update stats", %{respondent: respondent} do
    NuntiumChannel.update_stats(respondent, ReplyHelper.multiple(["Hello!", "Do you exercise?"]))

    assert Repo.get(Respondent, respondent.id).stats == %Ask.Stats{
      total_received_sms: 1,
      total_sent_sms: 2
    }
  end
end
