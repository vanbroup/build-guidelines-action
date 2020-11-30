FROM pandoc/latex:2.9.2.1

# Install the necessary LaTeX packages
RUN tlmgr install \
  crimsonpro \
  draftwatermark \
  enumitem \
  everypage \
  fancyhdr \
  parskip \
  sourcecodepro \
  sourcesanspro \
  sourceserifpro \
  titlesec \
  tocloft \
  xecjk

# Install bash
RUN apk add bash

RUN mkdir -p /tmp/fonts && \
    mkdir -p /usr/share/fonts && \
    wget -O /tmp/fonts/noto.zip https://noto-website-2.storage.googleapis.com/pkgs/NotoSerifCJKjp-hinted.zip && \
    unzip /tmp/fonts/noto.zip -d /tmp/fonts && \
    chmod 0644 /tmp/fonts/*.otf && \
    cp /tmp/fonts/*.otf /usr/share/fonts && \
    fc-cache -f -v && \
    rm -rf /tmp/fonts

RUN mkdir -p /cabforum
RUN mkdir -p /cabforum/templates
RUN mkdir -p /cabforum/filters

COPY entrypoint.sh /cabforum/entrypoint.sh
COPY templates/ /cabforum/templates/
COPY filters/ /cabforum/filters/

ENTRYPOINT ["/cabforum/entrypoint.sh"]
