/// What's currently selected in the sidebar — either one of the user's own wish lists,
/// or one of their collaborative lists.
enum SidebarSelection: Hashable {
    case wishList(Int64)
    case collaborative(Int64)
}

/// Which section of the sidebar is "active," independent of whether that section
/// currently has a valid selected list (e.g. right after the last list in a section
/// is deleted). Drives which store's `selectedListId` the sidebar/detail reflect.
enum SidebarSection {
    case wishLists
    case collaborative
}
