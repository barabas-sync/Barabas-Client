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
	class FileMonitorClient
	{
		private Gee.Map<string, FileMonitor> file_monitors;
		private Gee.Map<string, DateTime?> deleted_files;
		
		private Client.Database database;

		public FileMonitorClient(Client.Database database)
		{
			this.database = database;
			file_monitors = new Gee.HashMap<string, FileMonitor>();
			deleted_files = new Gee.HashMap<string, DateTime?>();
			var select_paths = database.prepare("SELECT parentURI FROM LocalFile 
				    GROUP BY parentURI");
			while (select_paths.step() == Sqlite.ROW)
			{
				string uri = select_paths.column_text(0);
				GLib.File directory = GLib.File.new_for_uri(uri);
				try
				{
					GLib.FileMonitor monitor = directory.monitor(GLib.FileMonitorFlags.SEND_MOVED);
						
					if (monitor == null)
					{
						stdout.printf ("Creating monitor for %s failed\n", uri);
					}
					else
					{
						stdout.printf ("Monitoring %s\n", uri);
						file_monitors[uri] = monitor;
						monitor.changed.connect(file_event);
					}
				}
				catch (GLib.Error error)
				{
					stdout.printf ("Creating monitor for %s failed\n", uri);
				}
			}
			Timeout.add_seconds(120, clear_deleted_files_list);
		}
	
		public void add_directory(string uri)
		{
			if (!file_monitors.has_key(uri))
			{
				GLib.File directory = GLib.File.new_for_uri(uri);
				stdout.printf ("Monitoring %s\n", uri);
				try
				{
					GLib.FileMonitor monitor = directory.monitor(GLib.FileMonitorFlags.SEND_MOVED);
					file_monitors[uri] = monitor;
					monitor.changed.connect(file_event);
				}
				catch (GLib.Error error)
				{
					// FIXME: do something sensible here
				}
			}
			else
			{
				stdout.printf ("Was already monitoring %s\n", uri);
			}
		}
	
		public signal void file_changed(SyncedFile file);
	
		private void file_event(GLib.File file, GLib.File? other_file, FileMonitorEvent type)
		{
			switch (type)
			{
				case FileMonitorEvent.CHANGED:
					file_edited(file);
					break;
				case FileMonitorEvent.CHANGES_DONE_HINT:
					file_edited(file);
					break;
				case FileMonitorEvent.MOVED:
					file_renamed(file, other_file);
					break;
				case FileMonitorEvent.DELETED:
					file_deleted(file);
					break;
				case FileMonitorEvent.CREATED:
					file_created(file);
					break;
				default:
					// We are not intrested in
					//  * unmounts
					//	* attribute changes
					break;
			}
		}
	
		private void file_edited(GLib.File file)
		{
			// If file is synchronized, queue for sync
			Client.LocalFile? local_file = null;
			try
			{
				local_file = Client.LocalFile.from_uri(file.get_uri(), database, false);
			}
			catch (GLib.Error error)
			{
				
			}
			if (local_file != null && local_file.is_synced())
			{
				if (!local_file.is_modified() || local_file.is_downloading())
				{
					// It is possible that this is our own download, so ignore
					stdout.printf("IGNORINGSSD\n");
					return;
				}
				Client.SyncedFile? synced_file = Client.SyncedFile.from_ID(database, local_file.syncedID);
				if (synced_file != null && synced_file.has_remote())
				{
					// See if the last version is uploaded, or uploading.
					// If so, add another version
					Client.SyncedFileVersion last_version = synced_file.versions().last();
					if (!last_version.is_uploading_or_uploaded())
					{
						last_version.deprecate();
						synced_file.remove_version(last_version);
					}
					DateTime date = new DateTime.now_local();
					Client.SyncedFileVersion new_version = new Client.SyncedFileVersion(
					    synced_file.ID,
					    "Version from " + date.format("%Y-%m-%d %H:%M") +  " at " + GLib.Environment.get_host_name(),
					    date,
					    database);
					synced_file.add_version(new_version);
					local_file.initiate_upload(synced_file, new_version);
				}
				else
				{
					GLib.log("file-monitor", LogLevelFlags.LEVEL_INFO, "File ID %lli not found?", local_file.syncedID);
				}
			}
		}
	
		private void file_renamed(GLib.File old_file, GLib.File new_file)
		{
			// Change the name in the database
			Client.LocalFile? local_file;
			try
			{
				local_file = Client.LocalFile.from_uri(old_file.get_uri(),
			                                           database,
			                                           false);

				if (local_file != null)
				{
					GLib.FileInfo file_info =
						new_file.query_info(GLib.FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME, 
						                    FileQueryInfoFlags.NONE,
						                    null);
					local_file.rename(file_info.get_display_name(),
						              new_file.get_uri());
				}
			}
			catch (GLib.Error error)
			{
				// FIXME: do something sensible here
				return;
			}
		}
	
		private void file_deleted(GLib.File file)
		{
			stdout.printf("DEL %s\n", file.get_uri());
			// Delete the file from our database
			Client.LocalFile? local_file;
			try
			{
				local_file = Client.LocalFile.from_uri(file.get_uri(),
			                                           database,
			                                           false);
			}
			catch (GLib.Error error)
			{
				// FIXME: do something sensible here
				return;
			}
			if (local_file != null)
			{
				deleted_files[file.get_uri()] = new DateTime.now_local();
			}
		}
		
		private void file_created(GLib.File file)
		{
			if (file.get_uri() in deleted_files.keys)
			{
				DateTime delete_time = deleted_files[file.get_uri()];
				TimeSpan difference = new DateTime.now_local().difference(delete_time);
				if (difference < TimeSpan.SECOND * 10)
				{
					deleted_files.unset(file.get_uri());
					file_edited(file);
				}
			}
		}
		
		private bool clear_deleted_files_list()
		{
			Gee.Map<string, DateTime?> deleted_files_swap = new Gee.HashMap<string, DateTime?>();
			foreach (string uri in deleted_files.keys)
			{
				DateTime delete_time = deleted_files[uri];
				TimeSpan difference = new DateTime.now_local().difference(delete_time);
				
				if (difference > TimeSpan.SECOND * 10)
				{
					Client.LocalFile? local_file;
					local_file = Client.LocalFile.from_uri(uri,
			                                               database,
			                                               false);
					if (local_file != null)
					{
						local_file.remove();
					}
				}
				else
				{
					deleted_files_swap[uri] = delete_time;
				}
			}
			deleted_files = deleted_files_swap;
			return true;
		}
	}
}
