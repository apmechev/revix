defmodule RevixWeb.EntryCollectionController do
  use RevixWeb, :controller

  alias Revix.Entries
  alias Revix.Likes

  action_fallback RevixWeb.FallbackController

  def likes(conn, %{"id" => id}) do
    with {:ok, entry} <- get_visible_entry(conn, id) do
      likes = Likes.get_active_likes_for_entry(entry.uri)
      items = Enum.map(likes, & &1.like_uri)

      activity(conn, %{
        "type" => "OrderedCollection",
        "id" => request_url(conn),
        "totalItems" => length(items),
        "orderedItems" => items
      })
    end
  end

  def replies(conn, %{"id" => id}) do
    with {:ok, entry} <- get_visible_entry(conn, id) do
      replies = Entries.get_comments_for_entry(entry.uri)
      items = Enum.map(replies, & &1.uri)

      activity(conn, %{
        "type" => "OrderedCollection",
        "id" => request_url(conn),
        "totalItems" => length(items),
        "orderedItems" => items
      })
    end
  end

  # The federation pipeline has no current_scope, so only public posts expose
  # their likes/replies collections to anonymous fetchers.
  defp get_visible_entry(conn, id) do
    with {:ok, entry} <- Entries.get_entry(id) do
      if Entries.visible_to?(entry, conn.assigns[:current_scope]) and
           (entry.type != :post or not is_nil(entry.published_at_utc)) do
        {:ok, entry}
      else
        {:error, :not_found}
      end
    end
  end
end
