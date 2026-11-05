# Numbering and references: additional contracts

Forward reference: \eqref{oracle:forward}; expected (A).
\begin{equation}x=y\tag{A}\label{oracle:forward}\end{equation}
Backward ref: \ref{oracle:forward}; expected A.
\begin{equation}a=b\label{oracle:auto}\end{equation}
Automatic equation reference: \eqref{oracle:auto}; expected (1).
\begin{equation*}c=d\end{equation*}
\begin{align}
x&=1\label{oracle:row}\\
y&=2\notag
\end{align}
First numbered row: \eqref{oracle:row}; expected (2).
\[z=3\tag*{B}\label{oracle:tagstar}\]
Tag-star ref: \ref{oracle:tagstar}; expected B.
Tag-star eqref: \eqref{oracle:tagstar}; expected (B).
