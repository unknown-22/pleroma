# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiFollowbotPolicy do
  alias Pleroma.User

  @behaviour Pleroma.Web.ActivityPub.MRF

  # XXX: this should become User.normalize_by_ap_id() or similar, really.
  defp normalize_by_ap_id(%{"id" => id}), do: User.get_cached_by_ap_id(id)
  defp normalize_by_ap_id(uri) when is_binary(uri), do: User.get_cached_by_ap_id(uri)
  defp normalize_by_ap_id(_), do: nil

  defp score_nickname("followbot@" <> _), do: 1.0
  defp score_nickname("federationbot@" <> _), do: 1.0
  defp score_nickname("federation_bot@" <> _), do: 1.0
  defp score_nickname(_), do: 0.0

  defp score_displayname("federation bot"), do: 1.0
  defp score_displayname("federationbot"), do: 1.0
  defp score_displayname("fedibot"), do: 1.0
  defp score_displayname(_), do: 0.0

  defp determine_if_followbot(%User{nickname: nickname, name: displayname}) do
    nick_score =
      nickname
      |> String.downcase()
      |> score_nickname()

    name_score =
      displayname
      |> String.downcase()
      |> score_displayname()

    nick_score + name_score
  end

  defp determine_if_followbot(_), do: 0.0

  @impl true
  def filter(%{"type" => "Follow", "actor" => actor_id} = message) do
    %User{} = actor = normalize_by_ap_id(actor_id)

    score = determine_if_followbot(actor)

    # TODO: scan biography data for keywords and score it somehow.
    if score < 0.8 do
      {:ok, message}
    else
      {:reject, nil}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}
end
