FROM pandoc/latex:2.9.2.1

# Install the necessary LaTeX packages
RUN tlmgr install \
  crimsonpro \
  draftwatermark \
  everypage \
  fancyhdr \
  parskip \
  sourcecodepro \
  sourcesanspro \
  sourceserifpro \
  titlesec \
  tocloft

# Install bash
RUN apk add bash

RUN mkdir -p /cabforum
RUN mkdir -p /cabforum/templates
RUN mkdir -p /cabforum/filters

COPY entrypoint.sh /cabforum/entrypoint.sh
COPY templates/ /cabforum/templates/
COPY filters/ /cabforum/filters/

ENTRYPOINT ["/cabforum/entrypoint.sh"]
