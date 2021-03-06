# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UploadedMedia do
  @moduledoc """
  """

  import Plug.Conn
  require Logger

  @behaviour Plug
  # no slashes
  @path "media"

  def init(_opts) do
    static_plug_opts =
      []
      |> Keyword.put(:from, "__unconfigured_media_plug")
      |> Keyword.put(:at, "/__unconfigured_media_plug")
      |> Plug.Static.init()

    %{static_plug_opts: static_plug_opts}
  end

  def call(conn = %{request_path: <<"/", @path, "/", file::binary>>}, opts) do
    config = Pleroma.Config.get([Pleroma.Upload])

    with uploader <- Keyword.fetch!(config, :uploader),
         proxy_remote = Keyword.get(config, :proxy_remote, false),
         {:ok, get_method} <- uploader.get_file(file) do
      get_media(conn, get_method, proxy_remote, opts)
    else
      _ ->
        conn
        |> send_resp(500, "Failed")
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp get_media(conn, {:static_dir, directory}, _, opts) do
    static_opts =
      Map.get(opts, :static_plug_opts)
      |> Map.put(:at, [@path])
      |> Map.put(:from, directory)

    conn = Plug.Static.call(conn, static_opts)

    if conn.halted do
      conn
    else
      conn
      |> send_resp(404, "Not found")
      |> halt()
    end
  end

  defp get_media(conn, {:url, url}, true, _) do
    conn
    |> Pleroma.ReverseProxy.call(url, Pleroma.Config.get([Pleroma.Upload, :proxy_opts], []))
  end

  defp get_media(conn, {:url, url}, _, _) do
    conn
    |> Phoenix.Controller.redirect(external: url)
    |> halt()
  end

  defp get_media(conn, unknown, _, _) do
    Logger.error("#{__MODULE__}: Unknown get startegy: #{inspect(unknown)}")

    conn
    |> send_resp(500, "Internal Error")
    |> halt()
  end
end
