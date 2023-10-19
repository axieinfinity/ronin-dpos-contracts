# Default network value
networkName="ronin-testnet"

# Function to print usage and exit
usage() {
    echo "Usage: $0 -c <network>"
    echo "  -c: Specify the network (ronin-testnet or ronin-mainnet)"
    exit 1
}

# Parse command-line options
while getopts "c:" opt; do
    case $opt in
    c)
        case "$OPTARG" in
        ronin-testnet)
            child_folder="ronin-testnet"
            networkName="ronin-testnet"
            ;;
        ronin-mainnet)
            child_folder="ronin-mainnet"
            networkName="ronin-mainnet"
            ;;
        *)
            echo "Unknown network specified: $OPTARG"
            usage
            ;;
        esac
        ;;
    *)
        usage
        ;;
    esac
done

# Shift the processed options out of the argument list
shift $((OPTIND - 1))

# Define the deployments folder by concatenating it with the child folder
folder="deployments/$child_folder"

# Check if the specified folder exists
if [ ! -d "$folder" ]; then
    echo "Error: The specified folder does not exist for the selected network."
    exit 1
fi

contractNames=(
    "RoninGovernanceAdmin"
    "MainchainGovernanceAdmin"
    "RoninValidatorSet"
    "BridgeTracking"
    "RoninGatewayV2"
    "SlashIndicator"
    "Staking"
    "Profile"
    "MockPrecompile"
    "NotifiedMigrator"
    "MainchainGatewayV2"
    "FastFinalityTracking"
    "RoninTrustedOrganization"
    "RoninValidatorSetTimedMigrator"
    "StakingVesting"
    "BridgeReward"
    "BridgeSlash"
    "RoninBridgeManager"
)

for contractName in "${contractNames[@]}"; do
    # Check if contractName is not empty
    if [ -n "$contractName" ]; then
        # Initialize arrays to store events and errors keys
        events_keys=()
        errors_keys=()

        # Get events and errors JSON data
        events=$(forge inspect "$contractName" events)
        errors=$(forge inspect "$contractName" errors)

        # Extract keys and populate the arrays
        while read -r key; do
            events_keys+=("\"event $key\"")
        done <<<"$(echo "$events" | jq -r 'keys[]')"

        while read -r key; do
            errors_keys+=("\"$key\"")
        done <<<"$(echo "$errors" | jq -r 'keys[]')"

        # Combine keys from events and errors
        all_keys=("${events_keys[@]}" "${errors_keys[@]}")

        # Call cast upload-signature
        echo cast upload-signature "${all_keys[@]}"
        cast upload-signature "${all_keys[@]}"
    else
        echo "Error: Missing contractName"
    fi
done
