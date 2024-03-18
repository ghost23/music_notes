## The grid

The basis for rendering of the music score is the grid. Its rows are represented by the
staff lines. In addition to the five visible staff lines of a typical staff we also add invisible
staff lines above and beneath the visible ones to complete our rows in the grid. This allows us
to position notes which later on will have ledger lines. Each staff has its individual grid. So
in a situation, where we have multiple staffs (like for the left and right hand in piano music),
each staff would have its own grid.

The columns of a grid are dynamic and nested. At the first level we have the measures. At the
second level within each measure we have the columns. The number of columns in a measure is
determined by the shortest note (or rest note) in that measure. For example, if the shortest note
(or rest note) is a 16th, then we will have at least 16 columns in that particular measure. In
addition to these columns, where we later will put the notes in, we might also have columns for
elements like clefs, the time signature, common accidentals and the bar lines. Those additional
columns are optional and only used, if we want to display any of these additional elements.