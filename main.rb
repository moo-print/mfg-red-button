require 'cli/ui'
require 'aws-sdk-lambda'

class AWS
    def get_status(lambda_client)
        lambda_client.list_functions().filter_map do |response|
            response.functions.filter_map do |function|
                tag_response = lambda_client.list_tags({resource: function.function_arn})
                if (tag_response.tags['Project'] == "moo-mfg" && tag_response.tags['Environment'] == "dev")
                    function.function_name
                else
                    nil
                end
            end
        end
    end
end

# Init the UI
CLI::UI::StdoutRouter.enable

# Configure the AWS connection
lambda_client = Aws::Lambda::Client.new

# Get env
environment = CLI::UI.ask("Environment?", default: "dev")
lambdas = []

# Display UI
CLI::UI::Frame.open("#{environment} Status") do
    sg = CLI::UI::SpinGroup.new
    sg.add('Fetching Lambdas...') { |spinner| lambdas = AWS.new.get_status(lambda_client); spinner.update_title('Fetched Lambas'); }
    sg.wait
    puts lambdas
end
