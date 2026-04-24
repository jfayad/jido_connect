# Authoring Integrations

Provider packages use `use Jido.Connect` and declare integration metadata,
auth profiles, actions, and triggers. The Spark DSL compiles the declaration
into a `Jido.Connect.Spec` and generated Jido modules.

Generated modules are adapters. Provider business logic belongs in handler
modules referenced by the DSL.
