require 'uri'
require 'rest-client'
require_relative './LocalizationSmartcatInfo.rb'

module Pixab

  class LocalizationSmartcatImport

    attr_accessor :project, :collection, :format, :tags, :completion_state, :conflicting_values, :delete_file_after_import

    def initialize()
      @delete_file_after_import = false
    end

    def run(commands = nil)
      commands.each_index do |index|
        command = commands[index]
        case command
        when '--ab'
          @project = LocalizationSmartcatInfo::Project_AirBrush
          @collection = 'AirBrush'
          @tags = 'iOS,android'
          @conflicting_values = 'skip'
        when '--abtest'
          @project = LocalizationSmartcatInfo::Project_AirBrush_test
          @collection = 'merge_test'
          @tags = 'iOS,android'
          @conflicting_values = 'skip'
        end
      end

      commands.each_index do |index|
        command = commands[index]
        case command
        when '--project'
          @project = commands[index + 1]
        when '--collection'
          @collection = commands[index + 1]
        when '--format'
          @format = commands[index + 1]
        when '--tags'
          @tags = commands[index + 1]
        when '--completion-state'
          @completion_state = commands[index + 1]
        when '--conflicting-values'
          @conflicting_values = commands[index + 1]
        when '--delete-file-after-import'
          @delete_file_after_import = true
        when '--keep-file-after-import'
          @delete_file_after_import = false
        end
      end

      import_localization_from_directory(Dir.pwd)

    end

    #  遍历目录上传本地化文案
    def import_localization_from_directory(directory)
      import_url = "https://smartcat.com/api/integration/v2/project/#{@project}/import"
      entries = []
      Dir.foreach(directory) do |entry|
        if entry.start_with?(".")
          next
        end

        if File.basename(entry, File.extname(entry)) == 'en'
          entries.unshift(entry)
        else
          entries.push(entry)
        end
      end

      puts "\n》》》》》正在上传本地化文案 》》》》》》》》》》\n".green

      entries.each do |entry|
        file_path = "#{directory}/#{entry}"
        import_params = generate_import_params_from_file_name(entry)
        import_id = import_localization(import_url, import_params, file_path)
        puts "#{entry} 正在上传中，上传ID：#{import_id}"
        if @delete_file_after_import
          File.delete(file_path) if File.exist?(file_path)
        end
      end 

      puts "\n》》》》》本地化文案上传已完成 》》》》》》》》》》\n".green
      puts "提示：由于Smartcat后台延迟，上传文案可能需要等待1-2分钟才能在后台全部显示。"

    end

    # 导入本地化文案
    def import_localization(import_url, import_params, file_path)
      uri = URI(import_url)
      uri.query = URI.encode_www_form(import_params)
      response = RestClient::Request.execute(
        method: :post,
        url: uri.to_s,
        user: LocalizationSmartcatInfo::USERNAME,
        password: LocalizationSmartcatInfo::PASSWORD,
        payload: {
          multipart: true,
          file: File.new(file_path, 'rb')
        }
      )
      return response.body
    end

    # 通过文件名称获取上传参数
    def generate_import_params_from_file_name(file_name)
      params = {}

      unless @collection.nil?
        params['collection'] = @collection
      end

      file_base_name = File.basename(file_name, File.extname(file_name))
      params['language'] = file_base_name

      unless @format.nil?
        params['format'] = @format
      end

      unless @tags.nil?
        params['labels'] = @tags
      end

      unless @completion_state.nil?
        params['completion-state'] = @completion_state
      end

      unless @conflicting_values.nil?
        if @conflicting_values == 'skip'
          params['skip-conflicting-values'] = nil
        elsif @conflicting_values == 'overwrite'
          params['overwrite-conflicting-values'] = nil
        end
      end

      return params
    end

    # 检查文件上传是否成功
    def check_import_status(import_id, max_retries=60)
      # 移除双引号
      import_id = import_id.tr('"','')
      retries = 0
      while retries < max_retries
        import_result_url = "https://smartcat.ai/api/v2/project/import-result/#{import_id}"
        uri = URI(import_result_url)
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(LocalizationSmartcatInfo::USERNAME, LocalizationSmartcatInfo::PASSWORD)
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        if response.code == "200"
          puts response.body
          retries += 1
          sleep(1)
        else
          puts response.body
          return false
        end

      end
    end

  end

end