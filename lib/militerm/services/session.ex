defmodule Militerm.Services.Session do
  @moduledoc """
  Note that this service needs to span all nodes, but can run on each node. It's the session
  information cache that has to be available regardless of which node the telnet session is on
  or which node the web session is on.

  So we use Cachex to provide the cross-node storage.
  """

  alias Militerm.Config

  alias MilitermWeb.Router.Helpers, as: Routes

  @doc """
  Given a callback (mfa), returns a URL that will trigger the MFA when an authenticated user
  visits the URL. The user_id will be appended to the provided args.
  """
  def get_authentication_url(module, function, args) do
    session_key = SecureRandom.urlsafe_base64()
    Militerm.Cache.Session.set(session_key, {module, function, args})
    Routes.session_url(MilitermWeb.Endpoint, :auth_session, session_key)
  end

  def authenticate_session(session_key, user_id) do
    case Militerm.Cache.Session.get(session_key) do
      {m, f, a} ->
        apply(m, f, a ++ [user_id])
        :ok

      _ ->
        :error
    end
  end
end
