defmodule Pleroma.MediaProxyTest do
  use ExUnit.Case
  import Pleroma.Web.MediaProxy

  describe "when enabled" do
    setup do
      enabled = Pleroma.Config.get([:media_proxy, :enabled])

      unless enabled do
        Pleroma.Config.put([:media_proxy, :enabled], true)
        on_exit(fn -> Pleroma.Config.put([:media_proxy, :enabled], enabled) end)
      end

      :ok
    end

    test "ignores invalid url" do
      assert url(nil) == nil
      assert url("") == nil
    end

    test "ignores relative url" do
      assert url("/local") == "/local"
      assert url("/") == "/"
    end

    test "ignores local url" do
      local_url = Pleroma.Web.Endpoint.url() <> "/hello"
      local_root = Pleroma.Web.Endpoint.url()
      assert url(local_url) == local_url
      assert url(local_root) == local_root
    end

    test "encodes and decodes URL" do
      url = "https://pleroma.soykaf.com/static/logo.png"
      encoded = url(url)

      assert String.starts_with?(
               encoded,
               Pleroma.Config.get([:media_proxy, :base_url], Pleroma.Web.base_url())
             )

      assert String.ends_with?(encoded, "/logo.png")

      assert decode_result(encoded) == url
    end

    test "encodes and decodes URL without a path" do
      url = "https://pleroma.soykaf.com"
      encoded = url(url)
      assert decode_result(encoded) == url
    end

    test "encodes and decodes URL without an extension" do
      url = "https://pleroma.soykaf.com/path/"
      encoded = url(url)
      assert String.ends_with?(encoded, "/path")
      assert decode_result(encoded) == url
    end

    test "encodes and decodes URL and ignores query params for the path" do
      url = "https://pleroma.soykaf.com/static/logo.png?93939393939&bunny=true"
      encoded = url(url)
      assert String.ends_with?(encoded, "/logo.png")
      assert decode_result(encoded) == url
    end

    test "validates signature" do
      secret_key_base = Pleroma.Config.get([Pleroma.Web.Endpoint, :secret_key_base])

      on_exit(fn ->
        Pleroma.Config.put([Pleroma.Web.Endpoint, :secret_key_base], secret_key_base)
      end)

      encoded = url("https://pleroma.social")

      Pleroma.Config.put(
        [Pleroma.Web.Endpoint, :secret_key_base],
        "00000000000000000000000000000000000000000000000"
      )

      [_, "proxy", sig, base64 | _] = URI.parse(encoded).path |> String.split("/")
      assert decode_url(sig, base64) == {:error, :invalid_signature}
    end

    test "uses the configured base_url" do
      base_url = Pleroma.Config.get([:media_proxy, :base_url])

      if base_url do
        on_exit(fn ->
          Pleroma.Config.put([:media_proxy, :base_url], base_url)
        end)
      end

      Pleroma.Config.put([:media_proxy, :base_url], "https://cache.pleroma.social")

      url = "https://pleroma.soykaf.com/static/logo.png"
      encoded = url(url)

      assert String.starts_with?(encoded, Pleroma.Config.get([:media_proxy, :base_url]))
    end
  end

  describe "when disabled" do
    setup do
      enabled = Pleroma.Config.get([:media_proxy, :enabled])

      if enabled do
        Pleroma.Config.put([:media_proxy, :enabled], false)

        on_exit(fn ->
          Pleroma.Config.put([:media_proxy, :enabled], enabled)
          :ok
        end)
      end

      :ok
    end

    test "does not encode remote urls" do
      assert url("https://google.fr") == "https://google.fr"
    end
  end

  defp decode_result(encoded) do
    [_, "proxy", sig, base64 | _] = URI.parse(encoded).path |> String.split("/")
    {:ok, decoded} = decode_url(sig, base64)
    decoded
  end
end
