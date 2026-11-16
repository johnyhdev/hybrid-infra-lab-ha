import importlib.util
import pathlib
import tempfile
import unittest
from unittest import mock

SOURCE = pathlib.Path(__file__).parents[1] / "roles" / "postgresql_ha" / "files" / "postgres_blob.py"
SPEC = importlib.util.spec_from_file_location("phase8_postgres_blob", SOURCE)
POSTGRES_BLOB = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(POSTGRES_BLOB)


class BlobBackupHelperTests(unittest.TestCase):
    def setUp(self):
        self.config = {
            "storage_account": "exampleaccount",
            "container": "postgres-backups",
            "cluster_name": "phase8-postgres",
            "managed_identity_client_id": "client-id",
        }

    def test_blob_url_encodes_segments_and_container_listing_path(self):
        self.assertEqual(
            POSTGRES_BLOB.blob_url(self.config, "cluster/base/a file.tar.gz"),
            "https://exampleaccount.blob.core.windows.net/postgres-backups/cluster/base/a%20file.tar.gz",
        )
        self.assertEqual(
            POSTGRES_BLOB.blob_url(self.config, "", "comp=list"),
            "https://exampleaccount.blob.core.windows.net/postgres-backups?comp=list",
        )

    def test_wal_restore_replaces_destination_only_after_complete_download(self):
        class Response:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self, _size=-1):
                if hasattr(self, "sent"):
                    return b""
                self.sent = True
                return b"complete-wal"

        with tempfile.TemporaryDirectory() as temporary_directory:
            destination = pathlib.Path(temporary_directory) / "000000010000000000000001"
            destination.write_bytes(b"old")
            with mock.patch.object(POSTGRES_BLOB, "request", return_value=Response()):
                POSTGRES_BLOB.restore_wal(self.config, "token", destination.name, destination)
            self.assertEqual(destination.read_bytes(), b"complete-wal")
            self.assertEqual(list(destination.parent.iterdir()), [destination])

    def test_wal_restore_preserves_existing_file_if_download_fails(self):
        class FailedResponse:
            def __enter__(self):
                raise OSError("network failure")

            def __exit__(self, *_args):
                return False

        with tempfile.TemporaryDirectory() as temporary_directory:
            destination = pathlib.Path(temporary_directory) / "wal-segment"
            destination.write_bytes(b"old")
            with mock.patch.object(POSTGRES_BLOB, "request", return_value=FailedResponse()):
                with self.assertRaises(OSError):
                    POSTGRES_BLOB.restore_wal(self.config, "token", destination.name, destination)
            self.assertEqual(destination.read_bytes(), b"old")
            self.assertEqual(list(destination.parent.iterdir()), [destination])

    def test_unsafe_wal_names_are_rejected_before_network_access(self):
        with mock.patch.object(POSTGRES_BLOB, "request") as request:
            with self.assertRaises(ValueError):
                POSTGRES_BLOB.archive_wal(self.config, "token", pathlib.Path("local"), "../escape")
        request.assert_not_called()


if __name__ == "__main__":
    unittest.main()
