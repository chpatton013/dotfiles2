export MISE_DATA_DIR="$(mise_data_dir)"
export MISE_CONFIG_DIR="$(mise_config_dir)"
export PATH="$(prepend_pathlist "$PATH" "$(mise_shims_dir)")"
