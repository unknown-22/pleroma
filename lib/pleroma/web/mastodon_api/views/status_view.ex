defmodule Pleroma.Web.MastodonAPI.StatusView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI.{AccountView, StatusView}
  alias Pleroma.{User, Activity}
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Repo

  # TODO: Add cached version.
  defp get_replied_to_activities(activities) do
    activities
    |> Enum.map(fn
      %{data: %{"type" => "Create", "object" => %{"inReplyTo" => inReplyTo}}} ->
        inReplyTo != "" && inReplyTo

      _ ->
        nil
    end)
    |> Enum.filter(& &1)
    |> Activity.create_activity_by_object_id_query()
    |> Repo.all()
    |> Enum.reduce(%{}, fn activity, acc ->
      Map.put(acc, activity.data["object"]["id"], activity)
    end)
  end

  def render("index.json", opts) do
    replied_to_activities = get_replied_to_activities(opts.activities)

    render_many(
      opts.activities,
      StatusView,
      "status.json",
      Map.put(opts, :replied_to_activities, replied_to_activities)
    )
  end

  def render(
        "status.json",
        %{activity: %{data: %{"type" => "Announce", "object" => object}} = activity} = opts
      ) do
    user = User.get_cached_by_ap_id(activity.data["actor"])
    created_at = Utils.to_masto_date(activity.data["published"])

    reblogged = Activity.get_create_activity_by_object_ap_id(object)
    reblogged = render("status.json", Map.put(opts, :activity, reblogged))

    mentions =
      activity.recipients
      |> Enum.map(fn ap_id -> User.get_cached_by_ap_id(ap_id) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> AccountView.render("mention.json", %{user: user}) end)

    %{
      id: to_string(activity.id),
      uri: object,
      url: object,
      account: AccountView.render("account.json", %{user: user}),
      in_reply_to_id: nil,
      in_reply_to_account_id: nil,
      reblog: reblogged,
      content: reblogged[:content],
      created_at: created_at,
      reblogs_count: 0,
      favourites_count: 0,
      reblogged: false,
      favourited: false,
      muted: false,
      sensitive: false,
      spoiler_text: "",
      visibility: "public",
      media_attachments: [],
      mentions: mentions,
      tags: [],
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: []
    }
  end

  def render("status.json", %{activity: %{data: %{"object" => object}} = activity} = opts) do
    user = User.get_cached_by_ap_id(activity.data["actor"])

    like_count = object["like_count"] || 0
    announcement_count = object["announcement_count"] || 0

    tags = object["tag"] || []
    sensitive = object["sensitive"] || Enum.member?(tags, "nsfw")

    mentions =
      activity.recipients
      |> Enum.map(fn ap_id -> User.get_cached_by_ap_id(ap_id) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> AccountView.render("mention.json", %{user: user}) end)

    repeated = opts[:for] && opts[:for].ap_id in (object["announcements"] || [])
    favorited = opts[:for] && opts[:for].ap_id in (object["likes"] || [])

    attachments =
      render_many(object["attachment"] || [], StatusView, "attachment.json", as: :attachment)

    created_at = Utils.to_masto_date(object["published"])

    reply_to = get_reply_to(activity, opts)
    reply_to_user = reply_to && User.get_cached_by_ap_id(reply_to.data["actor"])

    emojis =
      (activity.data["object"]["emoji"] || [])
      |> Enum.map(fn {name, url} ->
        name = HtmlSanitizeEx.strip_tags(name)

        url =
          HtmlSanitizeEx.strip_tags(url)
          |> MediaProxy.url()

        %{shortcode: name, url: url, static_url: url}
      end)

    %{
      id: to_string(activity.id),
      uri: object["id"],
      url: object["external_url"] || object["id"],
      account: AccountView.render("account.json", %{user: user}),
      in_reply_to_id: reply_to && to_string(reply_to.id),
      in_reply_to_account_id: reply_to_user && to_string(reply_to_user.id),
      reblog: nil,
      content: render_content(object),
      created_at: created_at,
      reblogs_count: announcement_count,
      favourites_count: like_count,
      reblogged: !!repeated,
      favourited: !!favorited,
      muted: false,
      sensitive: sensitive,
      spoiler_text: object["summary"] || "",
      visibility: get_visibility(object),
      media_attachments: attachments |> Enum.take(4),
      mentions: mentions,
      # fix,
      tags: [],
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: emojis
    }
  end

  def render("status.json", %{activity: %{data: %{"object" => object}} = activity} = opts) do
    created_at = Utils.to_masto_date(object["published"]) || "1970-01-01T00:00:00.000Z"

    %{
      id: to_string(activity.id),
      uri: object,
      url: object,
      account: %{
        id: 1,
        username: "pleroma",
        acct: "pleroma@pleroma.social",
        display_name: "Pleroma Error",
        locked: false,
        created_at: "1970-01-01T00:00:00.000Z",
        followers_count: 1,
        following_count: 1,
        statuses_count: 1,
        note: "This is not a real account",
        url: "https://git.pleroma.social/pleroma/pleroma/issues/233",
        avatar: "#{Web.base_url()}/images/avi.png",
        avatar_static: "#{Web.base_url()}/images/avi.png",
        header: "#{Web.base_url()}/images/banner.png",
        header_static: "#{Web.base_url()}/images/banner.png",
        emojis: [],
        fields: [],
        source: %{
          note: "",
          privacy: "public",
          sensitive: "false"
        }
      },
      in_reply_to_id: nil,
      in_reply_to_account_id: nil,
      reblog: nil,
      content: "Could not render this Activity. Missing StatusView.",
      created_at: created_at,
      reblogs_count: 0,
      favourites_count: 0,
      reblogged: false,
      favourited: false,
      muted: false,
      sensitive: false,
      spoiler_text: "",
      # let’s not share bugs
      visibility: "private",
      media_attachments: [],
      mentions: [],
      tags: [],
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: []
    }
  end

  def render("attachment.json", %{attachment: attachment}) do
    [%{"mediaType" => media_type, "href" => href} | _] = attachment["url"]

    type =
      cond do
        String.contains?(media_type, "image") -> "image"
        String.contains?(media_type, "video") -> "video"
        String.contains?(media_type, "audio") -> "audio"
        true -> "unknown"
      end

    <<hash_id::signed-32, _rest::binary>> = :crypto.hash(:md5, href)

    %{
      id: to_string(attachment["id"] || hash_id),
      url: MediaProxy.url(href),
      remote_url: href,
      preview_url: MediaProxy.url(href),
      text_url: href,
      type: type
    }
  end

  def get_reply_to(activity, %{replied_to_activities: replied_to_activities}) do
    _id = activity.data["object"]["inReplyTo"]
    replied_to_activities[activity.data["object"]["inReplyTo"]]
  end

  def get_reply_to(%{data: %{"object" => object}}, _) do
    if object["inReplyTo"] && object["inReplyTo"] != "" do
      Activity.get_create_activity_by_object_ap_id(object["inReplyTo"])
    else
      nil
    end
  end

  def get_visibility(object) do
    public = "https://www.w3.org/ns/activitystreams#Public"
    to = object["to"] || []
    cc = object["cc"] || []

    cond do
      public in to ->
        "public"

      public in cc ->
        "unlisted"

      # this should use the sql for the object's activity
      Enum.any?(to, &String.contains?(&1, "/followers")) ->
        "private"

      true ->
        "direct"
    end
  end

  def render_content(%{"type" => "Article"} = object) do
    summary = object["name"]

    content =
      if !!summary and summary != "" do
        "<p><a href=\"#{object["url"]}\">#{summary}</a></p>#{object["content"]}"
      else
        object["content"]
      end

    HtmlSanitizeEx.basic_html(content)
  end

  def render_content(object) do
    HtmlSanitizeEx.basic_html(object["content"])
  end
end
