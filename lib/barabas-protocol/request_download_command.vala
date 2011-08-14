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
	public class RequestDownloadCommand : ICommand
	{

		private SyncedFileVersion version;
		//private int64 commit_id;
		private string download_uri;
		private string connection_host;
	
		public override string command_type { get { return "requestDownload"; } }

		public RequestDownloadCommand (SyncedFileVersion version, string uri, string connection_host)
		{
			this.version = version;
			this.download_uri = uri;
			this.connection_host = connection_host;
		}

		public override Json.Generator? execute()
		{
			Json.Generator gen;
			var version_request = json_message(out gen);
		
			version_request.set_string_member("request", command_type);
			version_request.set_int_member("version-id", version.remoteID);
		
			// TODO: add different methods negotation (plain, rsync, ...)
		
			return gen;
		}
	
		public override void response (Json.Object response)
		{	
			/**
			 TODO: limit the number of uploads
			**/
			download.begin(response);
		}
	
		/*private bool on_commit_download(Json.Object request)
		{
			if (request.get_int_member("commit-id") == commit_id)
			{
				//this.client.remove_incoming_request_handler("commitDownload", this.on_commit_download);
				done = true;
				return true;
			}
	
			return false;
		}*/
	
		private async void download(Json.Object response)
		{
			//commit_id = response.get_int_member("commit-id");
			Json.Object channel_info = response.get_object_member("channel-info");
			int64 port = channel_info.get_int_member("port");
			string host = channel_info.get_string_member("host");
			if (host == null)
			{
				host = connection_host;
			}
			//this.client.add_incoming_request_handler("commitDownload", this.on_commit_download);

			var socket = new GLib.SocketClient();
			SocketConnection connection;
			try
			{
				connection = socket.connect_to_host(host, (uint16)port);
			}
			catch (GLib.Error connect_error)
			{
				// TODO: retry for a while
				return;
			}
			download_started();
		
			GLib.File file = GLib.File.new_for_uri (download_uri);
			try
			{
				yield file.create_async(GLib.FileCreateFlags.NONE, 0, null);
			}
			catch (GLib.IOError io_create_error)
			{
				// Catch the case the file already exists.
			}
			catch (GLib.Error create_error)
			{
				// Catch the case the file already exists.
			}
			
			try
			{
				GLib.FileIOStream stream = yield file.open_readwrite_async();
			
				int64 total_to_read = 0;
				int64 total_read = 0;
				ssize_t current_read = 1;
				uint8[] buffer = new uint8[1024];
				while (current_read > 0)
				{
					current_read = yield connection.input_stream.read_async(buffer);
					total_read += current_read;
					buffer.resize((int)current_read);
					if (current_read > 0)
					{
						yield stream.output_stream.write_async(buffer);
						download_progress((int64)total_read, total_to_read);
					}
				}
				stream.close();
				connection.close();
				download_stopped();
			}
			catch (GLib.IOError io_error)
			{
				// TODO: error handling
			}
			catch (GLib.Error error)
			{
				// TODO: error handling
			}
		}
		
		public signal void download_started();
		public signal void download_progress(int64 progress, int64 total);
		public signal void download_stopped();
	
	}
}
