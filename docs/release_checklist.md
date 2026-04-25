# Release Checklist

1. Run root package checks:

   ```sh
   mix format --check-formatted
   mix compile --warnings-as-errors
   mix test
   MIX_ENV=docs mix docs
   ```

2. Run demo checks:

   ```sh
   cd dev/demo
   mix format --check-formatted
   mix compile --warnings-as-errors
   mix test
   ```

3. Build packages:

   ```sh
   cd apps/jido_connect
   mix hex.build

   cd ../jido_connect_github
   mix hex.build

   cd ../jido_connect_slack
   mix hex.build
   ```

4. Publish order:

   ```sh
   cd apps/jido_connect
   mix hex.publish

   cd ../jido_connect_github
   mix hex.publish

   cd ../jido_connect_slack
   mix hex.publish
   ```

`dev/demo`, `.env`, `.secrets`, `_build`, `deps`, and generated docs are not
included in Hex packages.
