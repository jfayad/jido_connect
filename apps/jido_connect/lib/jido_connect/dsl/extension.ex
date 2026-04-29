defmodule Jido.Connect.Dsl.Extension do
  @moduledoc false

  @sections Jido.Connect.Dsl.Sections.sections()

  use Spark.Dsl.Extension,
    sections: @sections,
    verifiers: [Jido.Connect.Dsl.Verifiers.ValidateOperations],
    transformers: [Jido.Connect.Dsl.Transformers.BuildSpec]
end
