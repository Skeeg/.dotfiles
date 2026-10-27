package histfile

import (
	"errors"
	"time"
)

// File is a loaded history file plus what Rewrite needs to detect a
// concurrent write.
type File struct {
	Path    string
	Format  Format
	Entries []Entry
}

func Load(path string) (*File, error) {
	return nil, errors.New("not implemented")
}

// Rewrite removes the entries at the deleted indices. It backs the file up
// first and returns the backup path, or "" when nothing was deleted.
func (f *File) Rewrite(deleted []int, now time.Time) (backup string, err error) {
	return "", errors.New("not implemented")
}
