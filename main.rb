require 'cli/ui'
require 'aws-sdk-lambda'

# Init the UI
CLI::UI::StdoutRouter.enable

# Configure the AWS connection
lambda_client = Aws::Lambda::Client.new
lambda_list << lambda_client.list_functions().each do |response|
    response.functions.each do |function|
        function.function_name
    end
end

# Display UI
CLI::UI::Frame.open('Production Status') do
    puts lambda_list
end