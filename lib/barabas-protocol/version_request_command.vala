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
	public class VersionRequestCommand : ICommand
	{

		private SyncedFileVersion version_to_sync;
		private SyncedFile file_to_sync;
		private LocalFile local_file_to_upload;
	
		public override string command_type { get { return "requestVersion"; } }

		public VersionRequestCommand (LocalFile local_file,
		                              SyncedFile file_to_sync,
		                              SyncedFileVersion version_to_sync)
		{
			this.local_file_to_upload = local_file;
			this.version_to_sync = version_to_sync;
			this.file_to_sync = file_to_sync;
		}

		public override Json.Generator? execute ()
		{
			Json.Generator gen;
			var version_request = json_message(out gen);
		
			version_request.set_string_member("request", command_type);
			version_request.set_int_member("file-id", file_to_sync.remoteID);
		
			// TODO: add different methods negotation (plain, rsync, ...)
		
			return gen;
		}
	
		public override void response (Json.Object response)
		{	
			/**
			 TODO: limit the number of uploads
			**/
			upload.begin(response);
		}
	
		private async void upload (Json.Object response)
		{
			int64 commit_id = response.get_int_member("commit-id");
			Json.Object channel_info = response.get_object_member("channel-info");
			int64 port = channel_info.get_int_member("port");
			string host = channel_info.get_string_member("host");
	
			var socket = new GLib.SocketClient();
			
			GLib.SocketConnection connection = null;
			int connect_tries = 0;
			while (connection == null)
			{
				try
				{
					connection = socket.connect_to_host(host, (uint16)port);
				}
				catch (GLib.IOError error)
				{
					connect_tries++;
					GLib.Timeout.add(200, upload.callback);
					yield;
				}
			}
		
			version_to_sync.upload_started();
		
			GLib.File file = GLib.File.new_for_uri(local_file_to_upload.uri);
			GLib.FileInfo info = yield file.query_info_async(GLib.FILE_ATTRIBUTE_STANDARD_SIZE, GLib.FileQueryInfoFlags.NONE);
			GLib.FileIOStream stream = yield file.open_readwrite_async();
		
			ssize_t total_read = 0;
			int64 total_to_read = info.get_size();
			uint8[] buffer = new uint8[2048];
			GLib.log("network", LogLevelFlags.LEVEL_INFO, "Uploading");
			while (total_to_read > total_read)
			{
				ssize_t current_stride = yield stream.input_stream.read_async(buffer);
				buffer.resize((int)current_stride);
				total_read += current_stride;
				yield connection.output_stream.write_async(buffer);
				version_to_sync.upload_progressed((int64)total_read, total_to_read);
				
				GLib.Timeout.add(50, upload.callback);
				yield;
			}
		
			connection.close();
			
			success(version_to_sync, commit_id);
		}
	
		public signal void success(SyncedFileVersion file_version, int64 commit_id);
	}
}
