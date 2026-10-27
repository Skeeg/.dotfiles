package histfile

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

// File is a loaded history file plus what Rewrite needs to detect a
// concurrent write.
type File struct {
	Path    string
	Format  Format
	Entries []Entry

	real    string // Path with symlinks resolved; the file actually written
	data    []byte
	size    int64
	modTime time.Time
	mode    os.FileMode
}

func Load(path string) (*File, error) {
	real, err := filepath.EvalSymlinks(path)
	if err != nil {
		return nil, err
	}
	fh, err := os.Open(real)
	if err != nil {
		return nil, err
	}
	defer fh.Close()
	info, err := fh.Stat()
	if err != nil {
		return nil, err
	}
	data, err := io.ReadAll(fh)
	if err != nil {
		return nil, err
	}
	if int64(len(data)) != info.Size() {
		return nil, fmt.Errorf("%s changed while being read; try again", path)
	}
	format, entries := Parse(data)
	return &File{
		Path: path, Format: format, Entries: entries,
		real: real, data: data, size: info.Size(), modTime: info.ModTime(), mode: info.Mode().Perm(),
	}, nil
}

// Rewrite removes the entries at the deleted indices. It backs the file up
// first and returns the backup path, or "" when nothing was deleted. If
// the file changed since Load, it writes nothing and returns an error;
// the backup it already made is returned alongside.
func (f *File) Rewrite(deleted []int, now time.Time) (backup string, err error) {
	if len(deleted) == 0 {
		return "", nil
	}

	backup = BackupPath(f.Path, now)
	if err := writeExclusive(backup, f.data); err != nil {
		return "", fmt.Errorf("backup failed, nothing written: %w", err)
	}

	drop := make(map[int]bool, len(deleted))
	for _, i := range deleted {
		drop[i] = true
	}
	var kept []byte
	for i, e := range f.Entries {
		if !drop[i] {
			kept = append(kept, e.Raw...)
		}
	}

	tmp, err := os.CreateTemp(filepath.Dir(f.real), "."+filepath.Base(f.real)+".hist-clean-*")
	if err != nil {
		return backup, err
	}
	defer func() {
		if err != nil {
			os.Remove(tmp.Name())
		}
	}()
	if _, err = tmp.Write(kept); err != nil {
		tmp.Close()
		return backup, err
	}
	if err = tmp.Chmod(f.mode); err != nil {
		tmp.Close()
		return backup, err
	}
	if err = tmp.Sync(); err != nil {
		tmp.Close()
		return backup, err
	}
	if err = tmp.Close(); err != nil {
		return backup, err
	}

	info, err := os.Stat(f.real)
	if err != nil {
		return backup, err
	}
	if info.Size() != f.size || !info.ModTime().Equal(f.modTime) {
		err = fmt.Errorf("%s changed since it was read (a shell wrote to it?); nothing written", f.Path)
		return backup, err
	}
	if err = os.Rename(tmp.Name(), f.real); err != nil {
		return backup, err
	}
	return backup, nil
}

// BackupPath is where Rewrite at time now backs up the file at path.
func BackupPath(path string, now time.Time) string {
	return path + ".bak." + now.Format("20060102_150405")
}

// writeExclusive creates path with mode 0600, failing if it exists. A
// partial file left by a failed write is removed.
func writeExclusive(path string, data []byte) error {
	fh, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return err
	}
	_, err = fh.Write(data)
	if err == nil {
		err = fh.Sync()
	}
	if cerr := fh.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(path)
	}
	return err
}
