FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY sw.js /usr/share/nginx/html/sw.js
COPY manifest.webmanifest /usr/share/nginx/html/manifest.webmanifest
COPY nginx-landing.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
