/**
    This file is part of Barabas Client Library.

	Copyright (C) 2011 Nathan Samson
 
    Barabas Client Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas Client Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Barabas Client Library.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.Client
{
	class DownloadLogCommand : ICommand
	{
		private Database database;
		public override string command_type { get { return "downloadLog"; } }

		public DownloadLogCommand (Database database)
		{
			this.database = database;
		}

		public override Json.Generator? execute ()
		{
			GLib.log("network", LogLevelFlags.LEVEL_INFO, "Downloading log");
			Json.Generator gen;
			var create_file = json_message(out gen);
			create_file.set_string_member("request", "downloadLog");
			
			int64 latest_entry_id = HistoryLogEntry.find_latest_non_local(database);
			create_file.set_int_member("latest-entry", latest_entry_id);
			return gen;
		}
	
		public override void response (Json.Object response)
		{
			var log_entries = response.get_array_member("entries");
			sync_log.begin(log_entries);
		}
	
		private async void sync_log(Json.Array entries)
		{
			GLib.log("test", LogLevelFlags.LEVEL_INFO, "Download log entries: %u", entries.get_length());
			for (int current = 0; current < entries.get_length(); current++)
			{
				Json.Object json_entry = entries.get_object_element(current);
			
				int64 remote_id = json_entry.get_int_member("log-id");
				
				GLib.log("test", LogLevelFlags.LEVEL_INFO, "Handling: %lli", remote_id);
				
				HistoryLogEntry? db_entry = HistoryLogEntry.find_by_remote(remote_id, database);
				if (db_entry == null)
				{
					int64 file_id = json_entry.get_int_member("id");
					SyncedFile? file = SyncedFile.from_remote(database, file_id);
					
					string type = json_entry.get_string_member("type");
					GLib.log("test", LogLevelFlags.LEVEL_INFO, "Type = %s", type);
					
					
					if (type == "new-file")
					{
						string name = json_entry.get_string_member("name");
						string mimetype = json_entry.get_string_member("mimetype");
						
						db_entry = new HistoryLogEntry.from_new_file(remote_id,
						                                             file_id,
						                                             name,
						                                             mimetype,
						                                             false,
						                                             database);
						GLib.log("test", LogLevelFlags.LEVEL_INFO, "Inserting (new-file): %lli", remote_id);
						
						if (file != null)
						{
							continue;
						}
						
						file = new SyncedFile(database, 
						                      file_id,
						                      name,
						                      mimetype);
					}
					else if (type == "tag")
					{
						if (file == null)
						{
							// This is a little bit strange
							continue;
						}
						
						string tag_a = json_entry.get_string_member("tag");
						db_entry = new HistoryLogEntry.from_new_tag(remote_id,
						                                            file_id,
						                                            tag_a,
						                                            false,
						                                            database);
						
						GLib.log("test", LogLevelFlags.LEVEL_INFO, "Inserting tag: %lli", remote_id);
						
						file.tag_from_remote(tag_a);
					}
					else if (type == "untag")
					{
						if (file == null)
						{
							// This is a little bit strange
							continue;
						}
						
						string tag_b = json_entry.get_string_member("tag");
						db_entry = new HistoryLogEntry.from_remove_tag(remote_id,
						                                               file_id,
						                                               tag_b,
						                                               false,
						                                               database);
						file.untag_from_remote(tag_b);
					}
					else if (type == "new-version")
					{
						int64 version_id = json_entry.get_int_member("version-id");
						string version_name = json_entry.get_string_member("version-name");
						string time_edited_as_string = json_entry.get_string_member("version-timeedited");
						DateTime time_edited = from_barabas_date(time_edited_as_string);
					
						SyncedFileVersion? sf_version =
						    SyncedFileVersion.find_from_remote_id(version_id, database);
						
						db_entry = new HistoryLogEntry.from_new_version(remote_id,
						                                                file_id,
						                                                version_id,
						                                                version_name,
						                                                time_edited_as_string,
						                                                false,
						                                                database);
						
						if (sf_version == null)
						{
							sf_version = new SyncedFileVersion.from_remote(
						    	version_id, file_id, version_name, time_edited, database);
							file.remote_new_version(sf_version);
						}
					}
				}
				Idle.add(sync_log.callback);
				yield;
			}
			success();
		}
		
		public signal void success();
	}
}
