#!/usr/bin/env ruby
# encoding: UTF-8

require "fileutils"
require 'colored2'
require 'open3'
require_relative './GitUtils.rb'
require_relative './RepoManager.rb'

module Pixab

  class ComponentSynchronizer

    attr_accessor :is_need_build, :is_need_remote_repo, :is_need_pod_install, :is_use__target_branch
    attr_reader :repo_manager, :repos, :main_repo_name, :updated_repo_names
  
    def initialize(repo_manager = RepoManager.new, commands = nil)
      @repo_manager = repo_manager
      @is_need_build = false
      @is_need_remote_repo = false
      @is_need_pod_install = true
      @is_use__target_branch = true

      if commands.nil?
        return
      end
      commands.each_index do |index|
        command = commands[index]
        case command
        when "--build"
          @is_need_build = true
        when "--remote-repo"
          @is_need_remote_repo = true
        when "--no-pod-install"
          @is_need_pod_install = false
        when "--current-branch"
          @is_use__target_branch = false
        else
        end
      end

    end
  
    def run
      read_repo_infos

      active_repo_names = nil
      if is_need_remote_repo
        puts "\n》》》》》正在将本地调试仓替换为远程仓 》》》》》》》》》》\n".green
        active_repo_names = replace_local_to_remote
      end

      puts "\n》》》》》正在合并主工程代码 》》》》》》》》》》》》》》》\n".green
      merge_and_check 

      puts "\n》》》》》正在读取最新提交，并更新pod 》》》》》》》》》》\n".green
      replace_podfile

      if is_need_remote_repo 
        puts "\n》》》》》正在将远程仓复原为本地调试仓 》》》》》》》》》》\n".green
        reset_remote_to_local(active_repo_names)
      end

      if is_need_build
        puts "\n》》》》》正在进行Xcode编译 》》》》》》》》》》》》》》》\n".green
        FileUtils.cd("#{repo_manager.root_path}/#{main_repo_name}")
        build
      end
    end
  
    # 读取组件信息
    def read_repo_infos
      @repos = repo_manager.sub_repos
      @main_repo_name = repo_manager.main_repo["name"]
    end
  
    # 将本地调试仓修改为远程仓
    def replace_local_to_remote
      active_repo_names = ""
      repos.each do |repo|
        is_avtive = true
        components = repo["components"]
        if !components.nil?
          components.each do |component|
            if component["tool"] == "CocoaPods"
              is_avtive = !component["active"].empty?
              break
            end
          end
        end
        if is_avtive 
          active_repo_names += " #{repo["name"]}"
        end
      end
  
      if !active_repo_names.empty?
        system "mbox deactivate#{active_repo_names}"
        system "mbox pod install"
        Utilities.check_shell_result("Error: execute `mbox pod install` failed")
      end
      return active_repo_names
    end
  
    # 将远程仓重置为本地调试仓
    def reset_remote_to_local(active_repo_names)
      if active_repo_names.nil? || active_repo_names.empty?
        return
      end
      system "mbox activate#{active_repo_names}"
    end
  
    # 合并代码并检查冲突
    def merge_and_check
      system "mbox merge --repo #{main_repo_name}"
      FileUtils.cd("#{repo_manager.root_path}/#{main_repo_name}")
      `git --no-pager diff --check`
      conflict_hint = "Error: code conflict!\n"
      conflict_hint += "step1: Resolve `#{main_repo_name}` code conflicts\n"
      conflict_hint += "step2: Execute this script again"
      Utilities.check_shell_result(conflict_hint)
    end
  
    # 替换主工程Podfile
    def replace_podfile
      # 获取每个子库最新的commit id
      repo_commite_id = {}
      repos.each do |repo|
        repo_name = repo["name"]

        FileUtils.cd("#{repo_manager.root_path}/#{repo_name}")
        repo_target_branch = @is_use__target_branch ? repo_target_branch = repo["target_branch"] : GitUtils.current_branch
        next unless GitUtils.check_remote_branch_exists_fast("origin/#{repo_target_branch}")    

        stdout, status = Open3.capture2("git fetch origin #{repo_target_branch}")
        next unless status.success?

        commit_id = `git log origin/#{repo_target_branch} -n 1 --pretty=format:"%H"`
        if !commit_id.nil?
          repo_commite_id[repo_name] = commit_id
        end
      end
  
      podfile_path = "#{repo_manager.root_path}/#{main_repo_name}/AirBrushPodfiles/pix_ab_component.rb" 
      podfile_content = File.read(podfile_path)
      updated_repo_names = []
      repo_commite_id.each do |key, value|
        reg = /#{key}.+:commit => '(.+)'/
        podfile_content.match(reg)
        if $1 != value
          podfile_content.sub!($1,value)
          updated_repo_names.push(key)
        end
      end
  
      if !updated_repo_names.empty?
        File.open(podfile_path, "w+") do |aFile|
          aFile.syswrite(podfile_content)
        end
      end
  
      if is_need_pod_install
        system "mbox pod install --repo-update"
        Utilities.check_shell_result("Error: execute `mbox pod install --repo-update` failed")
      end

      @updated_repo_names = updated_repo_names
    end
  
    # 编译
    def build
      workspace_name = nil
      expect_ext = ".xcworkspace"
      Dir.foreach(Dir.pwd) do |entry|
        if File.extname(entry) == expect_ext
          workspace_name = entry
          break
        end
      end
  
      if workspace_name.nil?
        puts "Error: no workspace available for build".red
        exit(1)
      end
  
      scheme = File.basename(workspace_name, expect_ext)
  
      stdout, stderr, status = Open3.capture3("xcodebuild -workspace #{workspace_name} -scheme #{scheme} -showdestinations")
      reg = /{ platform:iOS,.+name:(?!Any iOS Devic)(.*) }/
      destinations = []
      stdout.scan(reg) do |match|
         destinations.push(match.first)
      end
      selected_item_name = nil
      if destinations.empty?
        puts "Error: no devices available for build".red
        exit(1)
      elsif destinations.length == 1
        selected_item_name = destinations.first
      else
        selected_item_name = Utilities.display_choose_list(destinations, [destinations.last],"设备","请选择编译设备").first
      end
      if selected_item_name.nil?
        exit(1)
      end
  
      system("xcodebuild -workspace #{workspace_name} -scheme #{scheme} -configuration Debug -destination 'platform=iOS,name=#{selected_item_name}'")
      Utilities.check_shell_result("Error: xcode build failed")
    end
  
  end
  
end