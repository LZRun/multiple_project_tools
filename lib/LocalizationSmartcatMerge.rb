
require_relative './LocalizationSmartcat.rb'
require_relative './LocalizationSmartcatImport.rb'

module Pixab 
  
  class LocalizationSmartcatMerge

    def run(commands=nil)
      download_params = []
      import_params = ["--delete-file-after-import"]
      commands.each_index do |index|
        command = commands[index]

        unless command.start_with?("--")
          next
        end

        if command == "--ab"
          download_params += ["--output", "{LANGUAGE}.json", "--tags", "ab"]
          import_params.push("--ab")
          next
        end

        if command == "--abtest"
          download_params += ["--output", "{LANGUAGE}.json", "--tags", "merge_test"]
          import_params.push("--abtest")
          next
        end

        if command.start_with?("--to-")
          import_params.push(command.sub("--to-", "--"))
          import_params.push(commands[index + 1])
        else
          download_params.push(command)
          download_params.push(commands[index + 1])
        end

      end

      LocalizationSmartcat.new.run(download_params)
      LocalizationSmartcatImport.new.run(import_params)
    end

  end
  
end