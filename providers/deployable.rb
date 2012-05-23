#
# Copyright Peter Donald
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include Chef::Asadmin

def version_file
  "#{node['glassfish']['domains_dir']}/#{new_resource.deployable_key}.VERSION"
end

action :deploy do

  ruby_block "create_#{new_resource.deployable_key}_version_file" do
    block do
      ::File.open(version_file, 'w') do |f2|
        f2.puts new_resource.version
      end
    end
    action :nothing
  end

  cached_package_filename = "#{Chef::Config[:file_cache_path]}/#{::File.basename(new_resource.url)}"
  remote_file cached_package_filename do
    source new_resource.url
    mode "0600"
    not_if { ::File.exists?(cached_package_filename) }
  end

  execute "deploy application #{new_resource.deployable_key}" do
    not_if "(#{asadmin_command('list-applications')} | grep -- '#{new_resource.deployable_key} ') && (cat #{version_file} | grep -x -- '#{new_resource.version}')"

    command = ""
    command << "deploy "
    command << "--name #{new_resource.deployable_key} "
    command << "--enabled=#{new_resource.enabled} "
    command << "--upload=#{new_resource.upload} "
    command << "--force=#{new_resource.force} "
    command << "--type #{new_resource.type} " if new_resource.type
    command << "--contextroot=#{new_resource.context_root} " if new_resource.context_root
    command << "--virtualservers=#{new_resource.virtual_servers.join(",")} "
    command << cached_package_filename

    command asadmin_command(command)
    notifies :create, resources(:ruby_block => "create_#{new_resource.deployable_key}_version_file"), :immediately
  end
end

action :undeploy do
  execute "undeploy application #{new_resource.deployable_key}" do
    only_if "#{asadmin_command('list-applications')} | grep -- '#{new_resource.deployable_key} '"
    command asadmin_command("undeploy #{new_resource.deployable_key}")
  end
end
