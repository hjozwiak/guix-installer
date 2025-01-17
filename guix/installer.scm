;;; Copyright © 2019, 2023 Alex Griffin <a@ajgrf.com>
;;; Copyright © 2019 Pierre Neidhardt <mail@ambrevar.xyz>
;;; Copyright © 2019 David Wilson <david@daviwil.com>
;;; Copyright © 2023 Hunter Jozwiak <hunter.t.joz@gmail.com>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Generate a bootable image (e.g. for USB sticks, etc.) with:
;; $ guix system image -t iso9660 installer.scm

(define-module (nongnu system install)
  #:use-module (gnu services)
  #:use-module (gnu services ssh)
  #:use-module (gnu services sound)
  #:use-module (gnu services configuration)
  #:use-module (gnu services linux)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu system)
  #:use-module (gnu system install)
  #:use-module (gnu packages speech)
  #:use-module (gnu packages accessibility)
  #:use-module (nongnu packages linux)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages mtools)
  #:use-module (gnu packages package-management)
  #:use-module (guix)
  #:export (installation-os-accessible))

(define-configuration/no-serialization espeakup-configuration
  (espeakup
   (file-like espeakup)
   "Set the package providing the @code{/bin/espeakup} command.")
  (default-voice
    (string "en-US")
    "Set the voice that espeak-ng should use by default."))

(define (espeakup-shepherd-service config)
  (list (shepherd-service
         (provision '(espeakup))
         (requirement '(user-processes))
         (documentation "Run espeakup, the espeak-ng bridge to speakup.")
         (start
          #~(make-forkexec-constructor
             (list #$(file-append (espeakup-configuration-espeakup config)
                                  "/bin/espeakup")
                   "-V" #$(espeakup-configuration-default-voice config))))
         (stop #~(make-kill-destructor)))))

(define espeakup-service-type
  (service-type
   (name 'espeakup)
   (extensions
    (list (service-extension
           shepherd-root-service-type
           espeakup-shepherd-service)
          (service-extension
           kernel-module-loader-service-type
           (const (list "speakup_soft")))))
   (default-value (espeakup-configuration))
   (description
    "Configure and run espeakup, a lightweight bridge between espeak-ng and speakup.")))
(define installation-os-accessible
  (operating-system
   (inherit installation-os)
   ;; Add the 'net.ifnames' argument to prevent network interfaces
   ;; from having really long names.  This can cause an issue with
   ;; wpa_supplicant when you try to connect to a wifi network.
   (kernel linux)
   (firmware (list linux-firmware))
   (kernel-arguments '("quiet" "modprobe.blacklist=radeon" "net.ifnames=0" "console=ttyS0,115200" "speakup.synth=soft"))

   (services
    (cons*
;;; Todo unmute all the audio channels.
     (service alsa-service-type)
     (service espeakup-service-type)
     (modify-services (operating-system-user-services installation-os)
                      (openssh-service-type config =>
                                            (openssh-configuration
                                             (inherit config)
                                             (allow-empty-passwords? #t)
                                             (%auto-start? #t))))))

   ;; Add some extra packages useful for the installation process
   (packages
    (append (list espeak-ng espeakup git curl stow vim emacs-no-x-toolkit alsa-utils)
            (operating-system-packages installation-os)))))

installation-os-accessible
