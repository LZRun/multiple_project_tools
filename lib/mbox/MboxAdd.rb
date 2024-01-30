require 'open3'
require_relative './AirBrushProjectInfo.rb'
require_relative '../Utilities.rb'
require_relative '../RepoManager.rb'

module Pixab

  class MboxAdd

    attr_reader :repo_manager

    def initialize(repo_manager)
      @repo_manager = repo_manager
    end

    def run(commands)
      if commands.empty?
        repo_names = get_all_sub_repo_names
        if !repo_names.empty?
          selected_item_names = Utilities.display_choose_list(repo_names, nil, "仓库", "请选择需要添加的仓库：", nil, nil, true)
          selected_item_names.each do |repo_name|
            add_repo([repo_name.strip, AirBrushProjectInfo::DEFAULT_BRANCH])
          end
        end
      elsif commands[0] == "--all"
        repo_names = get_all_sub_repo_names
        repo_names.each do |repo_name|
          add_repo([repo_name, AirBrushProjectInfo::DEFAULT_BRANCH])
        end
      else
        add_repo(commands)
      end

      system("mbox status")

    end

    def add_repo(commands)
      return if commands.empty?

      execute_commad = "mbox add"
      commands.each do |command|
        execute_commad += " #{command}"
      end

      stdout, status = Open3.capture2(execute_commad)
      if status.success?
        pull_lfs_files_if_needed(commands[0])
      end
    end

    # 获取所有的子仓名
    def get_all_sub_repo_names
      podfile_path = "#{@repo_manager.root_path}/#{@repo_manager.main_repo_name}/#{AirBrushProjectInfo::COMPONENT_FILE_PATH}" 
      podfile_content = File.read(podfile_path)
      matches = podfile_content.match(/def pix_ab_component(.*?)end/m)
      return [] if matches.nil?
      podfile_content = matches[0]
      reg = /'([^']+).+:commit => '(.+)'/
      matches = podfile_content.scan(reg)
      repo_names = matches.map do |match|
        match[0]
      end
      repo_names - @repo_manager.sub_repo_names
    end

    # 如果使用了lfs，则拉取lfs文件
    def pull_lfs_files_if_needed(repo_name)
      # 使用此方法切换路径时可以避免在控制台打印路径，并在执行完成后会切换回原路径
      FileUtils.cd("#{@repo_manager.root_path}/#{repo_name}") do
        break unless File.exist?(".gitattributes")

        file_content = File.read(".gitattributes")
        break unless file_content.include?("filter=lfs")

        Open3.capture3("mbox git hooks --disable")
        `git lfs pull`
        Open3.capture3("mbox git hooks --enable")
      end
    end

  end

end