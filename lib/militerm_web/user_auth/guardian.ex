defmodule MilitermWeb.UserAuth.Guardian do
  use Guardian, otp_app: :militerm

  alias Militerm.Accounts

  def subject_for_token(%{id: user_id} = resource, _claims) do
    {:ok, to_string(user_id)}
  end

  def resource_from_claims(%{"sub" => user_id} = _claims) do
    {:ok, Accounts.get_user!(user_id)}
  rescue
    Ecto.NoResultsError -> {:error, :resource_not_found}
  end
end
