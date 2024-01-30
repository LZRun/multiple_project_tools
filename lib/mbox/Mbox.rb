require_relative './MboxAdd.rb'
require_relative './MboxRemove.rb'

module Pixab
  
  class  Mbox

    attr_reader :repo_manager

    def initialize
      @repo_manager = RepoManager.new
    end

    def run(commands)
      if commands.empty?
        puts "请输入命令".red
        return
      end

      command = commands[0]
      case command
      when "add"
        MboxAdd.new(repo_manager).run(commands[1..-1])
      when "remove"
        MboxRemove.new(repo_manager).run(commands[1..-1])
      else
        `mbox #{commands.join(" ")}`
      end
    end

  end
  
end