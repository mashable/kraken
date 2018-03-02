# config valid only for current version of Capistrano
lock "3.9.0"

set :application, "Kraken"
set :repo_url, "git@github.com:mashable/kraken.git"

set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids')

# ec2 deployment target selection
# ----------------------------------------------------------------------
set :ec2_region, %w(us-east-1)
set :ec2_filter, 'tag:Project' => 'Kraken*', 'tag:Stages' => '*%s*' % fetch(:stage)
set :ec2_config, 'config/ec2.yml'

ec2_role :app, user: 'kraken', roles: %w(poller)

namespace :gui do
  task :start do
    on roles(:app) do
      execute :supervisorctl, "start kraken-gui"
    end
  end

  task :stop do
    on roles(:app) do
      execute :supervisorctl, "stop kraken-gui"
    end
  end

  task :restart do
    on roles(:app) do
      execute :supervisorctl, "restart kraken-gui"
    end
  end
end

namespace :app do
  task :start do
    on roles(:app) do
      execute :supervisorctl, "start kraken:"
    end
  end

  task :stop do
    on roles(:app) do
      execute :supervisorctl, "stop kraken:"
    end
  end

  task :restart do
    on roles(:app) do
      execute :supervisorctl, "restart kraken:"
    end
  end
end

namespace :connectors do
  task :setup do
    on roles(:app).first do
      within release_path do
        with soles_env: fetch(:stage) do
          execute :ruby, "bin/kraken", "connectors", "setup"
        end
      end
    end
  end

  task :status do
    on roles(:app).first do
      within release_path do
        with soles_env: fetch(:stage) do
          execute :ruby, "bin/kraken", "connectors", "status"
        end
      end
    end
  end
end

before 'app:restart', 'connectors:setup'
after 'deploy:finished', 'app:restart' unless ENV['NO_APP_RESTART'] || ENV['NO_RESTART']
after 'deploy:finished', 'gui:restart' unless ENV['NO_GUI_RESTART'] || ENV['NO_RESTART']