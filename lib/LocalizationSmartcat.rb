require 'net/http'
require 'uri'
require 'zip'

module Pixab

  class LocalizationSmartcat

    # 设置基本认证信息
    USERNAME = '4c8b26ac-ff12-427f-a460-afaacbb3fa3c'
    PASSWORD = '6_nDd3whcOZQHv5dPAusbq5Wmfl'
    Localization_FILE_NAME = 'Localization.zip'

    Project_AirBrush = '6cd2db15-6325-43ae-9087-f78aca9bec9a'

    attr_accessor :projects, :tags, :platform, :collections

    def initialize()
      @projects = Project_AirBrush
      @collections = 'main'
    end

    def run(commands = nil)
      commands.each_index do |index|
        command = commands[index]
        case command
        when '--ab-android'
          @platform = 'android'
          @tags = 'android'
          @collections = 'AirBrush'
        when '--ab-iOS'
          @tags = 'iOS'
          @collections = 'AirBrush'
        end
      end

      commands.each_index do |index|
        command = commands[index]
        case command
        when '--projects'
          @projects = commands[index + 1] 
        when '--tags' 
          @tags = commands[index + 1]
        when '--platform'
          @platform = commands[index + 1]
        when '--collections'
          @collections = commands[index + 1]
        end
      end

      export_url = "https://smartcat.com/api/integration/v2/project/#{projects}/export"
      export_params = generate_export_params
      download_url = 'https://smartcat.com/api/integration/v1/document/export'

      puts "\n》》》》》正在导出本地化文案 》》》》》》》》》》\n".green
      export_id = fetch_export_id(export_url, export_params)
      export_id = export_id.tr('"','')
      puts "\n》》》》》正在下载本地化文案 》》》》》》》》》》\n".green
      if download_zip_file_with_retry(download_url, export_id)
        puts "\n》》》》》正在替换本地化文案 》》》》》》》》》》\n".green
        unzip_file(Localization_FILE_NAME, extract_location)
        puts "Export ID #{export_id} has been downloaded and extracted."
      end

    end

    # 第一步：通过POST请求获取export ID
    def fetch_export_id(export_url, export_params)
      uri = URI(export_url)
      uri.query = URI.encode_www_form(export_params)

      request = Net::HTTP::Post.new(uri)
      request.basic_auth(USERNAME,PASSWORD)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      return response.body
    end

    # 第二步：循环尝试下载ZIP文件
    def download_zip_file_with_retry(download_url, export_id, max_retries=30)
      retries = 0
      while retries < max_retries
        uri = URI("#{download_url}/#{export_id}")
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(USERNAME,PASSWORD)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        if response.code == "200"
          File.open(Localization_FILE_NAME, "wb") { |file| file.write(response.body) }
          return true
        else
          sleep 1 # 等待1秒后重试
          retries += 1
        end
      end

      puts "Failed to download after #{max_retries} retries. Export ID: #{export_id}"
      return false
    end

    # 第三步：解压缩ZIP文件
    def unzip_file(zip_path)
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |f|
          f_path = f.name
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f,f_path) { true }
        end
      end

      File.delete(zip_path) if File.exist?(zip_path)

    end

    def generate_export_params()

      export_params = {
        'collections' => collections,
        'completion-state' => 'final',
        'fallback-to-default-language' => nil,
        'include-default-language' => nil,
      }

      if !platform.nil?
        format
        template
        if platform == 'android'
          format = 'android-xml'
          template = 'values-{LOCALE:ANDROID}/strings_ph.xml'
        else
          format = 'ios-strings'
          template = '{LOCALE:IOS}.lproj/Localizable.strings'
        end
        export_params['format'] = format
        export_params['output-file-path-template'] = template
      end

      if !tags.nil?
        export_params['labels'] = tags
      end

      return export_params
    end

  end

end