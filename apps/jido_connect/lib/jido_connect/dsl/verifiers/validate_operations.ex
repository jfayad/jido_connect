defmodule Jido.Connect.Dsl.Verifiers.ValidateOperations do
  @moduledoc false

  use Spark.Dsl.Verifier

  alias Jido.Connect.Dsl.OperationRules
  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    case OperationRules.violations(dsl_state, Verifier) do
      [] -> :ok
      violations -> {:error, Enum.map(violations, &OperationRules.dsl_error/1)}
    end
  end
end
