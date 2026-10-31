# BoxTurtle is a library: this configuration is only used when developing and
# testing BoxTurtle itself. It is never loaded by projects that depend on it.
import Config

import_config "#{config_env()}.exs"
