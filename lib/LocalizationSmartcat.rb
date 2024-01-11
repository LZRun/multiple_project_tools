require 'net/http'
require 'uri'
require 'zip'
require 'colored2'
require 'nokogiri'
require_relative './LocalizationSmartcatInfo.rb'

module Pixab

  class LocalizationSmartcat

    Localization_FILE_NAME = 'Localization.zip'

    attr_accessor :projects, :tags, :platform, :collections, :languages, :format, :output

    def initialize()
      @projects = LocalizationSmartcatInfo::Project_AirBrush
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
          @languages = 'en,ru,tr,de,fr,zh-Hans,zh-Hant,pt-BR,es,ar'
        when '--ab-iOS'
          @platform = 'iOS'
          @tags = 'iOS'
          @collections = 'AirBrush'
          @languages = 'en,ru,tr,de,fr,zh-Hans,zh-Hant,pt-BR,es,ar'
        when '--abv-iOS'
          @projects = LocalizationSmartcatInfo::Project_AirBrushVideo
          @platform = 'iOS'
          @tags = 'iOS'
        when '--abv-android'
          @projects = LocalizationSmartcatInfo::Project_AirBrushVideo
          @platform = 'android'
          @tags = 'android'
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
        when '--languages'
          @languages = commands[index + 1]
        when '--format'
          @format = commands[index + 1]
        when '--output'
          @output = commands[index + 1]
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
        unzip_file(Localization_FILE_NAME)
        puts "\n》》》》》本地化文案更新已完成 》》》》》》》》》》\n".green
      end

    end

    # 第一步：通过POST请求获取export ID
    def fetch_export_id(export_url, export_params)
      uri = URI(export_url)
      uri.query = URI.encode_www_form(export_params)

      request = Net::HTTP::Post.new(uri)
      request.basic_auth(LocalizationSmartcatInfo::USERNAME, LocalizationSmartcatInfo::PASSWORD)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      return response.body
    end

    # 第二步：循环尝试下载ZIP文件
    def download_zip_file_with_retry(download_url, export_id, max_retries=60)
      retries = 0
      while retries < max_retries
        uri = URI("#{download_url}/#{export_id}")
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(LocalizationSmartcatInfo::USERNAME, LocalizationSmartcatInfo::PASSWORD)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        if response.code == "200"
          File.open(Localization_FILE_NAME, "wb") { |file| file.write(response.body) }
          return true
        else
          retries += 1
          dots = '.' * retries
          print "\r#{dots}"
          # 等待1秒后重试
          sleep 1
        end
      end

      puts "\nFailed to download after #{max_retries} retries. Export ID: #{export_id}"
      return false
    end

    # 第三步：解压缩ZIP文件
    def unzip_file(zip_path)
      Zip::File.open(zip_path) do |zip_file|
        case platform
        when 'android'
          unzip_file_android(zip_file)
        when 'iOS'
          unzip_file_iOS(zip_file)
        else
          unzip_file_common(zip_file)          
        end
      end

      File.delete(zip_path) if File.exist?(zip_path)

    end

    def unzip_file_common(zip_file)
      zip_file.each do |f|
        f_path = f.name
        FileUtils.mkdir_p(File.dirname(f_path))
        File.delete(f_path) if File.exist?(f_path)
        f.extract(f_path)
      end
    end

    def unzip_file_iOS(zip_file)
      zip_file.each do |f|
        if is_ignored_file_path(f.name)
          next
        end
        f_path = extract_localization_file_path(f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        content = f.get_input_stream.read
        if projects == LocalizationSmartcatInfo::Project_AirBrush
          content = content.gsub(/=\s*".*";/) do |match|
            match.gsub('%s', '%@')
          end
        end
        File.write(f_path, content)
      end
    end

    def unzip_file_android(zip_file)
      zip_file.each do |f|
        if is_ignored_file_path(f.name)
          next
        end
        f_path = extract_localization_file_path(f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        content = f.get_input_stream.read
        document = Nokogiri::XML(content)
        document.traverse do |node|
          if node.text?
            node.content = node.content.gsub(/['"]/, '\\\\\0')
          end
        end
        File.write(f_path, document.to_xml)
      end
    end 

    def generate_export_params()

      export_params = {
        'collections' => collections,
        'completion-state' => 'final',
        'fallback-to-default-language' => nil,
        'include-default-language' => nil,
      }

      final_format = nil
      final_output = nil
      unless platform.nil?
        case platform
        when 'android'
          final_format = 'android-xml'
          if projects == LocalizationSmartcatInfo::Project_AirBrush
            final_output = '{LOCALE:ANDROID}/strings_ph.xml'
          else
            final_output = '{LOCALE:ANDROID}/strings.xml'
          end
        when 'iOS'
          final_format = 'ios-strings'
          final_output = '{LOCALE:IOS}.lproj/Localizable.strings'
        end
      end

      unless @format.nil?
        final_format = @format
      end
      unless @output.nil?
        final_output = @output
      end

      unless final_format.nil?
        export_params['format'] = final_format
      end
      unless final_output.nil?
        export_params['output-file-path-template'] = final_output
      end

      unless languages.nil?
        export_params['languages'] = languages
      end

      unless tags.nil?
        export_params['labels'] = tags
      end

      return export_params
    end

    def extract_localization_file_path(zip_file_path)
      case projects
      when LocalizationSmartcatInfo::Project_AirBrush
        if platform.nil? || platform != 'android'
          return zip_file_path
        end

        path = File.dirname(zip_file_path)
        localization = ''
        case path
        when 'en'
          localization = ''
        when 'fr'
          localization = '-fr-rFR'
        when 'ru'
          localization = '-ru-rRU'
        when 'zh-rHans'
          localization = '-zh-rCN'
        when 'tr'
          localization = '-tr-rTR'  
        when 'pt-rBR'
          localization = '-pt'
        else 
          localization = "-#{path}"
        end
        return "values#{localization}/#{File.basename(zip_file_path)}"
      
      when LocalizationSmartcatInfo::Project_AirBrushVideo
        if platform.nil?
          return zip_file_path
        end

        case platform 
        when 'android'
          path = File.dirname(zip_file_path)
          localization = ''
          case path
          when 'en'
            localization = ''
          when 'zh-rHans'
            localization = '-zh-rCN' 
          when 'zh-rHant'
            localization = '-zh-rHK'
          else 
            localization = "-#{path}"
          end
          return "values#{localization}/#{File.basename(zip_file_path)}"
        when 'iOS'
          path = File.dirname(zip_file_path)
          localization = zip_file_path
          case path
          when 'pt-PT.lproj'
            localization = File.join('pt.lproj', File.basename(zip_file_path))
          end
          return localization
        end
      end

      return zip_file_path
    end

    def is_ignored_file_path(file_path)
      case projects
      when LocalizationSmartcatInfo::Project_AirBrush
        return false unless platform == 'android'

        path = File.dirname(file_path)
        return path == 'zh-rHant' ? true : false
      end

      return false
    end

  end

end