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
	public class NewFileCommand : ICommand
	{
		private SyncedFile file_to_sync;
		public override string command_type { get { return "newFile"; } }

		public NewFileCommand(SyncedFile file)
		{
			this.file_to_sync = file;
		}

		public override Json.Generator? execute()
		{
			Json.Generator gen;
			var create_file = json_message(out gen);
			create_file.set_string_member("request", command_type);
			create_file.set_string_member("file-name", file_to_sync.display_name);
			create_file.set_string_member("mimetype", file_to_sync.mimetype);
			var tags = new Json.Array();
			foreach (string tag in file_to_sync.tags())
			{
				if (tag != "")
				{
					tags.add_string_element(tag);
				}
			}
			create_file.set_array_member("tags", tags);
			return gen;
		}
	
		public override void response(Json.Object response)
		{
			int64 remote_id = response.get_int_member("file-id");
			file_to_sync.set_remote(remote_id);
			success(file_to_sync);
		}
		
		public signal void success(SyncedFile file_to_sync);
	}
}
