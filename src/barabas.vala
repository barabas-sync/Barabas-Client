/**
    This file is part of Barabas DBUS Client.

	Copyright (C) 2011 Nathan Samson
 
    Barabas DBUS Client is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas DBUS Client is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Barabas DBUS Client.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.DBus.Server
{
	[DBus (name = "be.ac.ua.comp.Barabas")]
	public class MainServer : Object
	{
		public static void main(string[] args)
		{
			GLib.MainLoop loop = new GLib.MainLoop();
			
			try
			{
				new MainServer(loop);
				loop.run();
			}
			catch (Barabas.Client.DatabaseError error)
			{
				stderr.printf("Could not open database\n");
			}
			
		}
	
		private GLib.MainLoop main_loop;
		
		private DBusConnection dbus_connection;
		
		private string current_host;
		private Client.Connection client_connection;
		
		private Barabas.Client.Database database;
		private FileMonitorClient file_monitor_client;
	
		private ResourceManager<Search> current_searches;
		private ResourceManager<Download> current_downloads;
		private LocalFileResourceManager local_file_resource_manager;
	
		public MainServer(GLib.MainLoop loop) throws Barabas.Client.DatabaseError
		{
			this.main_loop = loop;
			Client.SyncedFile.cache = new Client.SyncedFileCache();
			Client.LocalFile.cache = new Client.LocalFileCache();
			
			Client.LocalFile.cache.added.connect(on_added_local_file);
			
			this.database = new Barabas.Client.Database();
			this.file_monitor_client = new FileMonitorClient(database);
			this.client_connection = new Client.Connection(database);
			Client.SyncedFile.cache.added.connect(on_new_synced_file);
			this.client_connection.status_changed.connect((status, msg) => {
			    status_changed(current_host, status, msg);
			});
			this.client_connection.user_password_authentication_request.connect(() => {
				user_password_authentication_request();
			});
			
			Bus.own_name (BusType.SESSION,
			              "be.ac.ua.comp.Barabas",
			              BusNameOwnerFlags.NONE,
					      (conn, name) => on_bus_aquired(conn, name),
					      () => {},
					      (conn, name) => on_busname_lost(conn, name));
		}
		
		private void on_bus_aquired(DBusConnection connection, string name)
		{
			this.dbus_connection = connection;
			local_file_resource_manager = new LocalFileResourceManager(connection);
			current_searches = new ResourceManager<Search>(connection,
			                       "/be/ac/ua/comp/Barabas/searches");
			current_downloads = new ResourceManager<Download>(connection,
			                       "/be/ac/ua/comp/Barabas/downloads");
			try
			{
				this.dbus_connection.register_object ("/be/ac/ua/comp/Barabas", this);
			}
			catch (IOError error)
			{
				stderr.printf("Could not register server object: %s\n", error.message);
				this.main_loop.quit();
			}
		}
		
		private void on_busname_lost(DBusConnection connection, string name)
		{
			stderr.printf("Could not own bus\n");
			this.main_loop.quit();
		}
		
		private void on_added_local_file(Client.LocalFile local_file)
		{
			local_file.initiate_upload.connect(on_initiate_upload);
			local_file.synced.connect(on_new_local_file);
			file_monitor_client.add_directory(local_file.parent_uri);
		}
		
		private void on_new_local_file(Client.LocalFile local_file,
		                               Client.SyncedFile synced_file)
		{
			DateTime date = new DateTime.now_local();
			Client.SyncedFileVersion file_version =
			    new Client.SyncedFileVersion(synced_file.ID,
			                                 "Initial version from " + GLib.Environment.get_host_name(),
			                                 date,
			                                 database);
			synced_file.add_version(file_version);
			local_file.initiate_upload(synced_file, file_version);
		}
		
		private void on_initiate_upload(Client.LocalFile local_file,
		                                Client.SyncedFile synced_file,
		                                Client.SyncedFileVersion file_version)
		{
			Client.VersionRequestCommand vr_command = new Client.VersionRequestCommand(local_file, synced_file, file_version, client_connection.connected_host);
			vr_command.success.connect(on_upload_ended);
			client_connection.queue_command(vr_command);
		}
		
		private void on_upload_ended(Client.SyncedFileVersion file_version,
		                             int64 remote_id)
		{
			client_connection.queue_command(new Client.VersionCommitCommand(file_version, remote_id));
		}

		/* Everything that has to do with the server status */

		public void enable_authentication_method(string method)
		{
			client_connection.enable_authentication_method(method);
		}

		public void connect_server(string hostname, int16 port = 2188)
		{
			current_host = hostname;
			client_connection.connect(hostname, port);
		}
		
		public void authenticate_user_password(Client.UserPasswordAuthentication auth)
		{
			client_connection.authenticate_user_password(auth);
		}
		
		public void authenticate_cancel()
		{
			client_connection.authenticate_cancel();
		}
		
		public signal void status_changed(string hostname,
		                                  Client.ConnectionStatus status,
		                                  string message);
		public signal void user_password_authentication_request();
		
		public void connect_cancel()
		{
			client_connection.connect_cancel();
		}

		public int search(string search_query)
		{
			Search search = new Search(search_query, database);
			return current_searches.add(search);
		}
		
		public int get_file_id_for_uri(string uri)
		{
			return local_file_resource_manager.get_id_for_uri(uri, (the_uri) => {
				Client.LocalFile local_file_client = Client.LocalFile.from_uri(uri, database);
				LocalFile local_file = new LocalFile(local_file_client, database);
				return local_file;
			});
		}
		
		public int create_local_copy_for_id(int64 id, string uri)
		{
			Client.SyncedFile client_synced_file = Client.SyncedFile.from_ID(database, id);
			Client.LocalFile client_local_file =
			    new Client.LocalFile.local_copy(uri,
			                                    client_synced_file,
			                                    database);
			LocalFile local_file = new LocalFile(client_local_file, database);
			return local_file_resource_manager.add(local_file);
		}
		
		public int download(string uri, int64 version_id)
		{
			Client.SyncedFileVersion version = Client.SyncedFileVersion.from_id(version_id, database);
			Client.RequestDownloadCommand download_command =
			    new Client.RequestDownloadCommand(version, uri, client_connection.connected_host);
			Download download = new Download(download_command);
			int id = current_downloads.add(download);
			
			download.start_requested.connect( (download_command) => {
				stdout.printf("QUEUEING\n");
				client_connection.queue_command(download_command);
			});
			return id;
		}
		
		private void on_new_synced_file(Client.SyncedFile synced_file)
		{
			if (synced_file.has_remote())
			{
				return;
			}
			Client.LocalFile? local_file = Client.LocalFile.from_file_id(synced_file.ID, 
			                                                             database);
			if (local_file != null)
			{
				file_monitor_client.add_directory(local_file.parent_uri);
			}
		}
	
		/* public string get_file_path_for_remote(int remote_id)
		{
			SyncedFile? file = SyncedFile.find_by_remote(database, remote_id);
		
			if (file == null)
			{
				return "";
			}
			else
			{
				return get_file_path(file.get_uri());
			}
		}
	
		public string get_version_path(int version_id)
		{
			if (version_id in mapped_file_versions.keys)
			{
				return version_id.to_string();
			}
			else
			{
				SyncedFileVersion? version = SyncedFileVersion.find(database, version_id);
				if (version == null)
				{
					return "";
				}
			
				string object_path = "/be/ua/ac/cmi/comp/Barabas/versions/".concat(version_id.to_string());
				connection.register_object(object_path, version);
				mapped_file_versions.set(version_id, version);
				return version_id.to_string();
			}
		}

		public string download_remote_to_uri(int remote_id, string uri)
		{
			SyncedFile synced_file = new SyncedFile.create(database, uri);
			publish_file(synced_file);
			request_queue.set(remote_id, synced_file);
	
			this.client.request_file_info(remote_id, on_request_info_arrived);
		
			return synced_file.get_uri().hash().to_string();
		}
	
		private void on_request_info_arrived(FileInfo info)
		{
			SyncedFile synced_file;
			request_queue.unset(info.remote_id, out synced_file);
			stdout.printf("SyncedFile %s\n", synced_file.get_uri());
			synced_file.from_remote(info);
			stdout.printf("SyncedFile2 %s\n", synced_file.get_uri());
			VersionListCommand version_list_command = new VersionListCommand(synced_file, database);
			stdout.printf("SyncedFile Crashed %s\n", synced_file.get_uri());
			version_list_command.completes.connect(() => {
				int[] versions = synced_file.versions();
				RequestDownloadCommand download_command =
					new RequestDownloadCommand(synced_file,
					                           versions[versions.length - 1],
					                           synced_file.get_uri());
				client.queue_command(download_command);
				stdout.printf("Queueing command\n");
			});
			this.client.queue_command(version_list_command);
		}
	
		public void search(string query)
		{
			this.client.search(query, on_search_completes);
		}
	
		public signal void search_completes(string query, int[] results);
	
		public void debug_quit()
		{
			//Gtk.quit();
		}
	
		private bool publish_file(SyncedFile file)
		{
			try
			{
				string id = file.get_uri().hash().to_string();
				this.client.listen(file);
				string object_path = "/be/ua/ac/cmi/comp/Barabas/files/".concat(id);
				connection.register_object(object_path, file);
				requested_files.set(id, file);
				file.managed.connect(on_new_managed_file);
				return true;
			}
			catch (IOError e)
			{
				return false;
			}
		}
	
		private void on_search_completes(string search, int[] results)
		{
			search_completes(search, results);
		}
	
		private void on_new_managed_file(SyncedFile synced_file)
		{
			GLib.File file = GLib.File.new_for_uri(synced_file.get_uri());
			file_monitor_client.add_directory(file.get_parent());
		}
	
		private void on_file_change(SyncedFile file)
		{
			switch (file.status)
			{
				case SyncedFile.Status.SYNCED:
					client.queue_command(new VersionRequestCommand(file, client));
					file.status = SyncedFile.Status.LOCAL_CHANGED;
					break;
				case SyncedFile.Status.LOCAL_CHANGED:
					// We already have queued a version request
					break;
				case SyncedFile.Status.REMOTE_CHANGED:
					// TODO: solve this
					break;
				case SyncedFile.Status.SYNCING:
					// We are syncing, so after that is finished we have to resync right away
					// TODO: fix this
					break;
				case SyncedFile.Status.NEW:
					// When the file is uploaded it will sync
					break;
				default:
					// No other statusses
					// TODO: throw a critical error
					break;
			}
		}*/
	}
}
