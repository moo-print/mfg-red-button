require 'cli/ui'
require 'aws-sdk-lambda'
require 'tty-table'

class AWS
    def get_lambdas(lambda_client)
        lambda_client.list_functions().map do |response|
            response.functions.map do |function|
                function.function_name
            end
        end.flatten
    end

    def get_event_source_mappings(lambda_client, function_name)
        mappings = lambda_client.list_event_source_mappings({function_name: function_name}).map do |response|
            response.event_source_mappings.map do |mapping|
                { 'ARN' => mapping.event_source_arn, 'State' => mapping.state, 'UUID' => mapping.uuid }
            end
        end.flatten
        mappings = 'None' if mappings.nil?
        mappings
    end

    def change_event_source_status(lambda_client, lambda_detail, status)
        lambda_detail.each do |detail|
            begin
                lambda_client.update_event_source_mapping({uuid: detail['UUID'], enabled: status})
            rescue
                puts CLI::UI.fmt "{{red:Failed to update #{detail['ARN']}}}"
            end
        end
    end

    def display_current_status(lambda_client)
        lambdas = []
        lambdas_with_mappings = {}

        # Display UI
        CLI::UI::Frame.open('Status') do
            sg = CLI::UI::SpinGroup.new
            sg.add('Fetching Lambdas...') { |spinner| lambdas = AWS.new.get_lambdas(lambda_client); spinner.update_title('Fetched Lambdas'); }
            sg.wait
            sg = CLI::UI::SpinGroup.new
            sg.add('Fetching Event Mappings...') { |spinner| lambdas.each do |function_name|
                lambdas_with_mappings[function_name] = AWS.new.get_event_source_mappings(lambda_client, function_name)
            end; spinner.update_title('Fetched Event Mappings'); }
            sg.wait
            table = TTY::Table.new(header: ['Lambda', 'Mapping', 'Enabled'])
            lambdas_with_mappings.each do |function_name, mappings|
                if (mappings.length == 0)
                    table << [function_name, 'None', '']
                elsif (mappings.length == 1)
                    table << [function_name, mappings[0]['ARN'], mappings[0]['State'] == 'Enabled' ? CLI::UI.fmt("{{v}}") : CLI::UI.fmt("{{x}}")]
                else
                    table << [function_name, 'Multiple', CLI::UI.fmt("{{?}}")]
                end
            end
            puts table.render(:unicode, alignments: [:left, :left, :center])
        end
        return lambdas_with_mappings
    end
end

# Init the UI
CLI::UI::StdoutRouter.enable

# Configure the AWS connection
lambda_client = Aws::Lambda::Client.new

# Display UI
lambdas_with_mappings = AWS.new.display_current_status(lambda_client)

# Drop the items that have no mappings
lambdas_with_mappings = lambdas_with_mappings.select {|k, v| v.length > 0 }

CLI::UI::Prompt.ask('Change Status?') do |handler|
    handler.option('No')  { |selection| puts CLI::UI.fmt "{{green:Done}}" }
    handler.option('Yes') { |selection|
        CLI::UI::Prompt.ask('New State?') do |handler|
            handler.option('Enable')  { |selection| 
                sg = CLI::UI::SpinGroup.new
                lambdas_with_mappings.filter.each do |lambda, detail|
                    sg.add("Enabling #{lambda} input...") { |spinner| AWS.new.change_event_source_status(lambda_client, detail, true); spinner.update_title("Enabled #{lambda} input"); }
                end
                sg.wait
                puts CLI::UI.fmt "{{green:Enabled}}"
            }
            handler.option('Disable') { |selection|
                sg = CLI::UI::SpinGroup.new
                lambdas_with_mappings.each do |lambda, detail|
                    sg.add("Disabling #{lambda} input...") { |spinner| AWS.new.change_event_source_status(lambda_client, detail, false); spinner.update_title("Disabled #{lambda} input"); }
                end
                sg.wait
                puts CLI::UI.fmt "{{red:Disabled}}"
            }
        end
        AWS.new.display_current_status(lambda_client);
    }
end
