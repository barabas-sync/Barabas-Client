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
	public class RemoveTagCommand : ICommand
	{
		private SyncedFile file_to_sync;
		private string removed_tag;
		public override string command_type { get { return "untag"; } }

		public RemoveTagCommand(SyncedFile file, string tag)
		{
			file_to_sync = file;
			removed_tag = tag;
		}

		public override Json.Generator? execute()
		{
			Json.Generator gen;
			var tag_op = json_message(out gen);
			tag_op.set_string_member("request", command_type);
			tag_op.set_string_member("tag", removed_tag);
			tag_op.set_int_member("file-id", file_to_sync.remoteID);
		
			return gen;
		}
	
		public override void response (Json.Object response)
		{
			file_to_sync.untag_from_remote(removed_tag);
		}
	}
}
