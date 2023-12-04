#!/usr/bin/env bash

# Function to display script usage information
show_help() {
  echo "Usage: $0 {dev|test|run|help} [--reset-cache] [--api-url API_URL] [--api-key API_KEY]"
  echo "  dev            : Start the Ontoportal Web UI development server."
  echo "                  Example: $0 dev --api-url http://localhost:9393 --api-key my_api_key"
  echo "                  Use --reset-cache to remove volumes: $0 dev --reset-cache"
  echo "  test           : Run tests."
  echo "  run            : Run a command in the Ontoportal Web UI Docker container."
  echo "  help           : Show this help message."
  echo
  echo "Description:"
  echo "  This script provides convenient commands for managing an Ontoportal Web UI"
  echo "  application using Docker Compose. It includes options for starting the development server,"
  echo "  running tests, and executing commands within the Ontoportal Web UI Docker container."
  echo
  echo "Goals:"
  echo "  - Simplify common tasks related to Ontoportal Web UI development using Docker."
  echo "  - Provide a consistent and easy-to-use interface for common actions."
}
# Function to update or create the .env file with API_URL and API_KEY
update_env_file() {
  local api_url="$1"
  local api_key="$2"

  # Update  the .env file with the provided values
  file_content=$(<.env_ui)

  # Make changes to the variable
  while IFS= read -r line; do
        if [[ "$line" == "API_URL="* ]]; then
          echo "API_URL=$api_url"
        elif [[ "$line" == "API_KEY="* ]]; then
          echo "API_KEY=$api_key"
        else
          echo "$line"
        fi
  done <<< "$file_content" > .env_ui
}

# Function to handle the "dev" option
dev() {
  echo "Starting Ontoportal Web UI development server..."
  

  local reset_cache=false
  local api_url=""
  local api_key=""

  # Check for command line arguments
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --reset-cache)
        reset_cache=true
        shift
        ;;
      --api-url)
        api_url="$2"
        shift 2
        ;;
      --api-key)
        api_key="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done

  # Check if arguments are provided
  if [ -n "$api_url" ] && [ -n "$api_key" ]; then
    # If arguments are provided, update the .env file
    update_env_file "$api_url" "$api_key"
  else
    # If no arguments, fetch values from the .env file
    source .env_ui
    api_url="$API_URL"
    api_key="$API_KEY"
  fi

  echo "api key : " $api_key
  echo "api url : " $api_url

  if [ -z "$api_url" ] || [ -z "$api_key" ]; then
    echo "Error: Missing required arguments. Please provide both --api-url and --api-key or update them in your .env"
    exit 1
  fi

  # Check if --reset-cache is present and execute docker compose down --volumes
  if [ "$reset_cache" = true ]; then
    echo "Resetting cache. Running: docker compose down --volumes"
    docker compose down --volumes
  fi

  echo "Run: bundle exec rails s -b 0.0.0.0 -p 3000"
  docker compose run --rm -it --service-ports rails bash -c "(bundle check || bundle install) && bin/rails db:prepare && bundle exec rails s -b 0.0.0.0 -p 3000"
}

# Function to handle the "test" option
test() {


  local api_url=""
  local api_key=""
  local test_options=""

  # Check for command line arguments
  while [ "$#" -gt 0 ]; do
     case "$1" in
       --api-url)
         shift
         api_url="$1"
         ;;
       *)

         if [ -z "$test_options" ]; then
           test_options="$1"
         else

           test_options="$test_options $1"
         fi
         ;;
     esac
     shift
  done

  if [ -z "$api_url" ]; then
      api_url=http://localhost:9393
      echo "Running API..."
      bin/run_api
  fi


  echo "api key : " $api_key
  echo "api url : " $api_url

  echo "Running tests..."
  echo "Run: API_URL=$api_url bundle exec rails test -v $test_options"

  docker compose run --rm -it test bash -c "(bundle check || bundle install) && RAILS_ENV=test && cp config/database.yml.sample config/database.yml && bin/rails db:prepare && API_URL=$api_url bundle exec rails test -v $test_options"

  # echo "Stopping API..."
  # bin/stop_api
}

# Function to handle the "run" option
run() {
  echo "Run: $*"
  docker compose run --rm -it rails bash -c "$*"
}

#create_config_files
# Main script logic
case "$1" in
  "run")
    run "${@:2}"
    ;;
  "dev")
    dev "${@:2}"
    ;;
  "test")
    test "${@:2}"
    ;;
  "help")
    show_help
    ;;
  *)
    show_help
    exit 1
    ;;
esac
