package selection

import (
	"reflect"
	"testing"

	"hist-clean/internal/audit"
)

// Two names: vbox-start with entries 1, 4, 7 and gti with entries 2, 9.
func fixture() *Selection {
	return New([]audit.Group{
		{Name: "vbox-start", Entries: []int{1, 4, 7}},
		{Name: "gti", Entries: []int{2, 9}},
	})
}

func assertMark(t *testing.T, s *Selection, g int, want Mark) {
	t.Helper()
	if got := s.Mark(g); got != want {
		t.Errorf("group %d: mark %v, want %v", g, got, want)
	}
}

func assertDeleted(t *testing.T, s *Selection, want []int) {
	t.Helper()
	got := s.Deleted()
	if len(got) == 0 && len(want) == 0 {
		return
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("Deleted() = %v, want %v", got, want)
	}
}

func TestStartsUnchecked(t *testing.T) {
	s := fixture()
	assertMark(t, s, 0, Unchecked)
	assertMark(t, s, 1, Unchecked)
	assertDeleted(t, s, nil)
}

func TestToggleUncheckedGoesFull(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	assertMark(t, s, 0, Full)
	assertMark(t, s, 1, Unchecked)
	assertDeleted(t, s, []int{1, 4, 7})
}

func TestToggleFullGoesUnchecked(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	assertMark(t, s, 0, Full)
	s.Toggle(0)
	assertMark(t, s, 0, Unchecked)
	assertDeleted(t, s, nil)
}

func TestToggleLineMakesPartial(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	s.ToggleLine(0, 1)
	assertMark(t, s, 0, Partial)
	if s.Line(0, 1) {
		t.Error("line 1 still ticked")
	}
	if !s.Line(0, 0) || !s.Line(0, 2) {
		t.Error("lines 0 and 2 should stay ticked")
	}
	assertDeleted(t, s, []int{1, 7})
}

func TestUntickingEveryLineGoesUnchecked(t *testing.T) {
	s := fixture()
	s.Toggle(1)
	s.ToggleLine(1, 0)
	assertMark(t, s, 1, Partial)
	s.ToggleLine(1, 1)
	assertMark(t, s, 1, Unchecked)
	assertDeleted(t, s, nil)
}

func TestRetickingEveryLineGoesFull(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	s.ToggleLine(0, 2)
	s.ToggleLine(0, 2)
	assertMark(t, s, 0, Full)
}

func TestTogglePartialGoesFull(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	s.ToggleLine(0, 0)
	s.Toggle(0)
	assertMark(t, s, 0, Full)
	assertDeleted(t, s, []int{1, 4, 7})
}

// Opening the line view on an unchecked name starts with every line ticked.
func TestOpenUncheckedTicksEveryLine(t *testing.T) {
	s := fixture()
	s.Open(0)
	assertMark(t, s, 0, Full)
	for l := 0; l < 3; l++ {
		if !s.Line(0, l) {
			t.Errorf("line %d not ticked", l)
		}
	}
}

func TestOpenPartialKeepsTicks(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	s.ToggleLine(0, 1)
	s.Open(0)
	assertMark(t, s, 0, Partial)
	assertDeleted(t, s, []int{1, 7})
}

func TestDeletedSpansGroupsInFileOrder(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	s.Toggle(1)
	s.ToggleLine(0, 1)
	assertDeleted(t, s, []int{1, 2, 7, 9})
}

func TestCounts(t *testing.T) {
	s := fixture()
	s.Toggle(0)
	s.Toggle(1)
	s.ToggleLine(1, 0)
	entries, names := s.Counts()
	if entries != 4 || names != 2 {
		t.Errorf("Counts() = (%d, %d), want (4, 2)", entries, names)
	}
}
