#!/usr/bin/env ruby
# encoding: UTF-8

require 'json'
require "fileutils"

module Pixab

  class RepoManager
  
    attr_reader :root_path, :feature
  
    def initialize()
      read_repo_infos
    end
  
    def read_repo_infos
      mbox_root = `mbox status --only root`
      Utilities.check_shell_result('Error: This is not `Mbox` directory')
      @root_path = mbox_root.split().last
  
      FileUtils.cd(root_path)
      json = File.read(".mbox/config.json")
      obj = JSON.parse(json)
      current_feature_name = obj["current_feature_name"]
      if current_feature_name.empty?
        puts "Error: You are currently in Free Mode".red
        exit(1)
      end
      @feature = obj["features"][current_feature_name.downcase]
    end
  
    def repos
     feature["repos"]
    end

    def main_repo
      repos.first
    end

    def main_repo_name
      main_repo["name"]
    end
  
    def sub_repos
      if repos.length > 1
        sub_repos = repos.dup
        sub_repos.delete_at(0)
        return sub_repos
      end
      return []
    end

    def sub_repo_names
      sub_repos.map do |sub_repo|
        sub_repo["name"]
      end
    end

    def feature_name
      feature["name"]
    end

    def feature_branch
      feature["branch_prefix"] + feature_name
    end
  
  end
  
end
