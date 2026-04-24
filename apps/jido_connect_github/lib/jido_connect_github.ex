defmodule Jido.Connect.GitHub do
  @moduledoc """
  First in-package GitHub integration authored with the Spark DSL.

  The action handlers expect a GitHub client module in
  `credentials.github_client`.
  """

  use Jido.Connect

  integration do
    id(:github)
    name("GitHub")
    category(:developer_tools)
    docs(["https://docs.github.com/rest"])
    metadata(%{package: :jido_connect_github})
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("GitHub OAuth user")
      authorize_url("https://github.com/login/oauth/authorize")
      token_url("https://github.com/login/oauth/access_token")
      callback_path("/integrations/github/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      scopes(["repo", "read:user"])
      default_scopes(["read:user"])
      pkce?(false)
      refresh?(false)
      revoke?(true)
    end
  end

  actions do
    action :list_issues do
      id("github.issue.list")
      label("List issues")
      description("List issues in a GitHub repository.")
      auth(:user)
      scopes(["repo"])
      mutation?(false)
      risk(:read)
      handler(Jido.Connect.GitHub.Handlers.Actions.ListIssues)

      input do
        field(:repo, :string, required?: true, example: "org/repo")
        field(:state, :string, enum: ["open", "closed", "all"], default: "open")
      end

      output do
        field(:issues, {:array, :map})
      end
    end

    action :create_issue do
      id("github.issue.create")
      label("Create issue")
      description("Create a GitHub issue.")
      auth(:user)
      scopes(["repo"])
      mutation?(true)
      risk(:write)
      confirmation(:required_for_ai)
      handler(Jido.Connect.GitHub.Handlers.Actions.CreateIssue)

      input do
        field(:repo, :string, required?: true, example: "org/repo")
        field(:title, :string, required?: true)
        field(:body, :string)
        field(:labels, {:array, :string}, default: [])
      end

      output do
        field(:number, :integer)
        field(:url, :string)
        field(:title, :string)
        field(:state, :string)
      end
    end
  end

  triggers do
    poll :new_issues do
      id("github.issue.new")
      label("New issues")
      description("Poll for new GitHub issues.")
      auth(:user)
      scopes(["repo"])
      interval_ms(300_000)
      checkpoint(:updated_at)
      dedupe(%{key: [:repo, :issue_number]})
      handler(Jido.Connect.GitHub.Handlers.Triggers.NewIssuesPoller)

      config do
        field(:repo, :string, required?: true, example: "org/repo")
      end

      signal do
        field(:repo, :string)
        field(:issue_number, :integer)
        field(:title, :string)
        field(:url, :string)
      end
    end
  end
end

defmodule Jido.Connect.GitHub.Handlers.Actions.ListIssues do
  @moduledoc false

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, issues} <-
           client.list_issues(
             Map.fetch!(input, :repo),
             Map.get(input, :state, "open"),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{issues: Enum.map(issues, &normalize_issue/1)}}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:error, :github_client_required}

  defp normalize_issue(issue) do
    %{
      number: Map.fetch!(issue, :number),
      url: Map.fetch!(issue, :url),
      title: Map.fetch!(issue, :title),
      state: Map.fetch!(issue, :state)
    }
  end
end

defmodule Jido.Connect.GitHub.Handlers.Actions.CreateIssue do
  @moduledoc false

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         attrs = %{
           title: Map.fetch!(input, :title),
           body: Map.get(input, :body),
           labels: Map.get(input, :labels, [])
         },
         {:ok, issue} <-
           client.create_issue(
             Map.fetch!(input, :repo),
             attrs,
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         number: Map.fetch!(issue, :number),
         url: Map.fetch!(issue, :url),
         title: Map.fetch!(issue, :title),
         state: Map.fetch!(issue, :state)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:error, :github_client_required}
end

defmodule Jido.Connect.GitHub.Handlers.Triggers.NewIssuesPoller do
  @moduledoc false

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, issues} <-
           client.list_new_issues(
             Map.fetch!(config, :repo),
             checkpoint,
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         signals: Enum.map(issues, &normalize_signal(config.repo, &1)),
         checkpoint: latest_checkpoint(issues, checkpoint)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:error, :github_client_required}

  defp normalize_signal(repo, issue) do
    %{
      repo: repo,
      issue_number: Map.fetch!(issue, :number),
      title: Map.fetch!(issue, :title),
      url: Map.fetch!(issue, :url)
    }
  end

  defp latest_checkpoint([], checkpoint), do: checkpoint

  defp latest_checkpoint(issues, _checkpoint) do
    issues
    |> Enum.map(&Map.get(&1, :updated_at))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort(:desc)
    |> List.first()
  end
end
