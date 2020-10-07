require 'cli/ui'
require 'aws-sdk-lambda'
require 'tty-table'

class AWS
    def get_lambdas(lambda_client)
        lambda_client.list_functions().filter_map do |response|
            response.functions.filter_map do |function|
                tag_response = lambda_client.list_tags({resource: function.function_arn})
                if (tag_response.tags['Project'] == "moo-mfg" && tag_response.tags['Environment'] == "dev")
                    function.function_name
                else
                    nil
                end
            end
        end.flatten
    end

    def get_event_source_mappings(lambda_client, function_name)
        mappings = lambda_client.list_event_source_mappings({function_name: function_name}).map do |response|
            response.event_source_mappings.map do |mapping|
                { mapping.event_source_arn => mapping.state }
            end
        end.flatten
        mappings = 'None' if mappings.nil?
        mappings
    end
end

# Init the UI
CLI::UI::StdoutRouter.enable

# Configure the AWS connection
lambda_client = Aws::Lambda::Client.new

# Get env
environment = CLI::UI.ask("Environment?", default: "dev")
lambdas = []
lambdas_with_mappings = {}

# Display UI
CLI::UI::Frame.open("#{environment} Status") do
    sg = CLI::UI::SpinGroup.new
    sg.add('Fetching Lambdas...') { |spinner| lambdas = AWS.new.get_lambdas(lambda_client); spinner.update_title('Fetched Lambdas'); }
    sg.wait
    sg = CLI::UI::SpinGroup.new
    sg.add('Fetching Event Mappings...') { |spinner| lambdas.each do |function_name|
        puts "handling #{function_name}"
        lambdas_with_mappings[function_name] = AWS.new.get_event_source_mappings(lambda_client, function_name)
    end; spinner.update_title('Fetched Event Mappings'); }
    sg.wait
    table = TTY::Table.new(["Lambda", "Mappings"])
    lambdas_with_mappings.each do |function_name, mappings|
        puts "adding #{function_name} with #{mappings}"
        table << [function_name, mappings]
    end
    puts table.render(:unicode)
end
