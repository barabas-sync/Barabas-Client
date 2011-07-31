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
		private int64 latest_entry;
		public override string command_type { get { return "downloadLog"; } }

		public DownloadLogCommand (Database database, int64 latest_entry)
		{
			this.latest_entry = latest_entry;
			this.database = database;
		}

		public override Json.Generator? execute ()
		{
			Json.Generator gen;
			var create_file = json_message(out gen);
			create_file.set_string_member("request", "downloadLog");
			create_file.set_int_member("latest-entry", latest_entry);
			return gen;
		}
	
		public override void response (Json.Object response)
		{
			var log_entries = response.get_array_member("entries");
			sync_log.begin(log_entries);
		}
	
		private async void sync_log(Json.Array entries)
		{
			for (int current = 0; current < entries.get_length(); current++)
			{
				Json.Object json_entry = entries.get_object_element(current);
			
				//int64 remote_id = json_entry.get_int_member("id");
				//HistoryLogEntry? db_entry = HistoryLogEntry.find_by_remote(database, remote_id);
				if (true)
				{
					int64 file_id = json_entry.get_int_member("id");
					SyncedFile? file = SyncedFile.from_remote(database, file_id);
					
					string type = json_entry.get_string_member("type");
					
					if (type == "new-file")
					{
						if (file != null)
						{
							continue;
						}
						string name = json_entry.get_string_member("name");
						string mimetype = json_entry.get_string_member("mimetype");
						
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
						file.tag_from_remote(json_entry.get_string_member("tag"));
					}
					else if (type == "remove-tag")
					{
						if (file == null)
						{
							// This is a little bit strange
							continue;
						}
						file.untag_from_remote(json_entry.get_string_member("tag"));
					}
					else if (type == "new-version")
					{
						int64 remoteID = json_entry.get_int_member("version-id");
						SyncedFileVersion sf_version = new SyncedFileVersion.from_remote(
						    remoteID, file_id, 0, database);
						file.remote_new_version(sf_version);
					}
				}
			}
		}
	}
}
